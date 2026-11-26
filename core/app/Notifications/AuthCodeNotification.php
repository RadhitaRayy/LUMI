<?php

namespace App\Notifications;

use App\Enums\AuthCodePurpose;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class AuthCodeNotification extends Notification
{
    use Queueable;

    public function __construct(
        public readonly string $code,
        public readonly AuthCodePurpose $purpose,
        public readonly int $ttlMinutes,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        // Sent in the user's language (User::preferredLocale), so these lines are translated.
        $intro = match ($this->purpose) {
            AuthCodePurpose::VerifyEmail => __('Enter this code in the Lumi app to verify your email.'),
            AuthCodePurpose::ResetPassword => __('Enter this code in the Lumi app to set a new password.'),
        };

        return (new MailMessage)
            ->subject($this->purpose->subject())
            ->greeting(__('Hi!'))
            ->line($intro)
            ->line("**{$this->code}**")
            ->line(__('The code works for :minutes minutes and can only be used once.', ['minutes' => $this->ttlMinutes]))
            ->line(__('If you did not ask for this code, you can ignore this email.'));
    }
}
