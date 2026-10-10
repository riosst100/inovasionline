<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\GoogleLoginRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Requests\Auth\SendPhoneOtpRequest;
use App\Http\Requests\Auth\UpdateAddressRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Http\Requests\Auth\VerifyPhoneRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\AuthService;
use App\Services\ChatService;
use App\Services\WhatsAppOtpService;
use App\Support\PhoneNumber;
use App\Support\Responses\ApiResponse;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function __construct(
        private readonly AuthService $authService,
        private readonly ChatService $chatService,
        private readonly WhatsAppOtpService $whatsAppOtpService,
    ) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $phone = $request->string('phone')->toString();

        if ($this->wantsToken($request) && ! $this->whatsAppOtpService->isRecentlyVerified($phone)) {
            return ApiResponse::error('Phone number is not verified.', [
                'phone' => ['Please verify this phone number via WhatsApp OTP first.'],
            ], 422);
        }

        $user = $this->authService->register($request->validated());

        if ($this->wantsToken($request)) {
            $user->forceFill(['phone_verified_at' => now()])->save();
            $this->whatsAppOtpService->clearVerification($phone);

            return ApiResponse::success(
                $this->tokenPayload($user, $request),
                'Registration successful.',
                [],
                201
            );
        }

        Auth::login($user);
        $request->session()->regenerate();

        return ApiResponse::success(new UserResource($user), 'Registration successful.', [], 201);
    }

    public function sendPhoneOtp(SendPhoneOtpRequest $request): JsonResponse
    {
        $phone = $request->string('phone')->toString();

        if (User::where('phone', $phone)->exists()) {
            return ApiResponse::error('This phone number is already registered.', [
                'phone' => ['This phone number is already registered.'],
            ], 422);
        }

        $this->whatsAppOtpService->send($phone);

        return ApiResponse::success(null, 'Verification code sent.');
    }

    public function verifyPhoneOtp(VerifyPhoneRequest $request): JsonResponse
    {
        $verified = $this->whatsAppOtpService->verify($request->string('phone')->toString(), $request->string('code')->toString());

        if (! $verified) {
            return ApiResponse::error('Invalid or expired verification code.', [
                'code' => ['Invalid or expired verification code.'],
            ], 422);
        }

        return ApiResponse::success(null, 'Phone number verified.');
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $identifier = $request->identifier();
        $field = filter_var($identifier, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';
        $value = $field === 'phone' ? PhoneNumber::normalize($identifier) : $identifier;

        $credentials = [$field => $value, 'password' => $request->string('password')->toString()];

        if ($this->wantsToken($request)) {
            if (! Auth::once($credentials)) {
                return ApiResponse::error('The provided credentials are incorrect.', [
                    'login' => ['The provided credentials are incorrect.'],
                ], 422);
            }

            return ApiResponse::success($this->tokenPayload(Auth::user(), $request), 'Login successful.');
        }

        if (! Auth::attempt($credentials, $request->boolean('remember'))) {
            return ApiResponse::error('The provided credentials are incorrect.', [
                'login' => ['The provided credentials are incorrect.'],
            ], 422);
        }

        $request->session()->regenerate();

        return ApiResponse::success(new UserResource(Auth::user()), 'Login successful.');
    }

    public function google(GoogleLoginRequest $request): JsonResponse
    {
        try {
            $user = $this->authService->loginWithGoogle($request->string('id_token')->toString());
        } catch (\RuntimeException) {
            return ApiResponse::error('The provided Google token is invalid.', [
                'id_token' => ['The provided Google token is invalid.'],
            ], 422);
        }

        if ($this->wantsToken($request)) {
            return ApiResponse::success($this->tokenPayload($user, $request), 'Login successful.');
        }

        Auth::login($user);
        $request->session()->regenerate();

        return ApiResponse::success(new UserResource($user), 'Login successful.');
    }

    public function logout(Request $request): JsonResponse
    {
        if ($request->user()?->currentAccessToken() instanceof \Laravel\Sanctum\PersonalAccessToken) {
            $request->user()->currentAccessToken()->delete();

            return ApiResponse::success(null, 'Logout successful.');
        }

        Auth::guard('web')->logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return ApiResponse::success(null, 'Logout successful.');
    }

    /**
     * Mobile/native clients (Flutter) authenticate via Bearer token instead of
     * cookie-based Sanctum sessions used by the Next.js SPA.
     */
    private function wantsToken(Request $request): bool
    {
        return $request->header('X-Client') === 'mobile';
    }

    private function tokenPayload(User $user, Request $request): array
    {
        $deviceName = $request->string('device_name')->toString() ?: 'mobile-device';

        $token = $user->createToken($deviceName)->plainTextToken;

        return [
            'user' => new UserResource($user),
            'token' => $token,
        ];
    }

    public function user(Request $request): JsonResponse
    {
        return ApiResponse::success(new UserResource($request->user()->load('seller')), 'User retrieved successfully.');
    }

    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->safe()->except('avatar');

        if ($request->hasFile('avatar')) {
            if ($user->avatar_path) {
                Storage::disk('public')->delete($user->avatar_path);
            }
            $data['avatar_path'] = $request->file('avatar')->store('avatars', 'public');
        }

        $user->update($data);

        return ApiResponse::success(new UserResource($user->fresh()->load('seller')), 'Profile updated successfully.');
    }

    public function updateAddress(UpdateAddressRequest $request): JsonResponse
    {
        $user = $request->user();
        $user->update($request->validated());

        $this->chatService->syncMembershipsForUser($user->fresh());

        return ApiResponse::success(new UserResource($user->fresh()->load('seller')), 'Address updated successfully.');
    }

    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        $status = Password::sendResetLink($request->only('email'));

        if ($status !== Password::RESET_LINK_SENT) {
            return ApiResponse::error('Unable to send reset link.', [
                'email' => [__($status)],
            ], 422);
        }

        return ApiResponse::success(null, 'Password reset link sent.');
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (\App\Models\User $user, string $password) {
                $user->forceFill([
                    'password' => Hash::make($password),
                    'remember_token' => Str::random(60),
                ])->save();

                event(new PasswordReset($user));
            }
        );

        if ($status !== Password::PASSWORD_RESET) {
            return ApiResponse::error('Unable to reset password.', [
                'email' => [__($status)],
            ], 422);
        }

        return ApiResponse::success(null, 'Password has been reset.');
    }
}
