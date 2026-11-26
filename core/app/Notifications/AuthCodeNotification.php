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
        $intro = match ($this->purpose) {
            AuthCodePurpose::VerifyEmail => 'Masukkan kode ini di aplikasi Lumi untuk memverifikasi email kamu.',
            AuthCodePurpose::ResetPassword => 'Masukkan kode ini di aplikasi Lumi untuk membuat password baru.',
        };

        return (new MailMessage)
            ->subject($this->purpose->subject())
            ->greeting('Halo!')
            ->line($intro)
            ->line("**{$this->code}**")
            ->line("Kode berlaku {$this->ttlMinutes} menit dan hanya bisa dipakai sekali.")
            ->line('Kalau kamu tidak meminta kode ini, abaikan email ini.');
    }
}
