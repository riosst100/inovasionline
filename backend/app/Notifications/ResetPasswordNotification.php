<?php

namespace App\Notifications;

use Illuminate\Auth\Notifications\ResetPassword as BaseResetPassword;
use Illuminate\Notifications\Messages\MailMessage;

class ResetPasswordNotification extends BaseResetPassword
{
    public function toMail($notifiable): MailMessage
    {
        $url = rtrim(config('app.frontend_url'), '/').'/reset-password?token='.$this->token.'&email='.urlencode($notifiable->getEmailForPasswordReset());

        return (new MailMessage)
            ->subject('Reset Kata Sandi')
            ->line('Anda menerima email ini karena kami menerima permintaan reset kata sandi untuk akun Anda.')
            ->action('Reset Kata Sandi', $url)
            ->line('Tautan reset kata sandi ini akan kedaluwarsa dalam '.config('auth.passwords.'.config('auth.defaults.passwords').'.expire').' menit.')
            ->line('Jika Anda tidak meminta reset kata sandi, tidak ada tindakan lebih lanjut yang diperlukan.');
    }
}
