<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Post\CreatePostCommentRequest;
use App\Http\Requests\Post\CreatePostRequest;
use App\Http\Requests\Post\SharePostRequest;
use App\Http\Resources\PostCommentResource;
use App\Http\Resources\PostResource;
use App\Models\Post;
use App\Models\PostComment;
use App\Services\PostService;
use App\Support\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use RuntimeException;

class PostController extends Controller
{
    public function __construct(private readonly PostService $postService) {}

    public function index(Request $request): JsonResponse
    {
        $viewer = Auth::guard('sanctum')->user();
        $paginator = $this->postService->feed($viewer, $request->integer('per_page', 15));

        return ApiResponse::paginated($paginator, PostResource::class, 'Feed retrieved successfully.');
    }

    public function store(CreatePostRequest $request): JsonResponse
    {
        $post = $this->postService->create(
            $request->user(),
            $request->only('body', 'product_ids', 'video_duration_seconds'),
            $request->file('media', []),
            $request->file('video'),
            $request->file('video_thumbnail'),
        );

        return ApiResponse::success(new PostResource($post), 'Post created successfully.', [], 201);
    }

    public function share(SharePostRequest $request, Post $post): JsonResponse
    {
        try {
            $shared = $this->postService->share($request->user(), $post, $request->string('body')->toString() ?: null);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 422);
        }

        return ApiResponse::success(new PostResource($shared), 'Post shared successfully.', [], 201);
    }

    public function destroy(Request $request, Post $post): JsonResponse
    {
        try {
            $this->postService->delete($request->user(), $post);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 403);
        }

        return ApiResponse::success(null, 'Post deleted successfully.');
    }

    public function toggleLike(Request $request, Post $post): JsonResponse
    {
        $liked = $this->postService->toggleLike($request->user(), $post);

        return ApiResponse::success([
            'liked' => $liked,
            'like_count' => $post->likes()->count(),
        ], $liked ? 'Post liked.' : 'Post unliked.');
    }

    public function comments(Request $request, Post $post): JsonResponse
    {
        $paginator = $this->postService->comments($post, $request->integer('per_page', 20));

        return ApiResponse::paginated($paginator, PostCommentResource::class, 'Comments retrieved successfully.');
    }

    public function storeComment(CreatePostCommentRequest $request, Post $post): JsonResponse
    {
        $comment = $this->postService->comment($request->user(), $post, $request->string('body')->toString());

        return ApiResponse::success(new PostCommentResource($comment), 'Comment added successfully.', [], 201);
    }

    public function destroyComment(Request $request, PostComment $comment): JsonResponse
    {
        try {
            $this->postService->deleteComment($request->user(), $comment);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), [], 403);
        }

        return ApiResponse::success(null, 'Comment deleted successfully.');
    }
}
