<?php

namespace App\Console\Commands;

use App\Enums\Role;
use App\Models\User;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

#[Signature('lumi:make-superadmin {email : Email of the owner account} {--name= : Display name for a new account}')]
#[Description('Create the Lumi owner account, or promote an existing user to superadmin')]
class MakeSuperadmin extends Command
{
    public function handle(): int
    {
        $email = strtolower((string) $this->argument('email'));

        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error("'{$email}' is not a valid email address.");

            return self::FAILURE;
        }

        $user = User::where('email', $email)->first();

        if ($user !== null) {
            $user->forceFill(['role' => Role::Superadmin, 'is_blocked' => false])->save();
            $this->info("{$email} is now a superadmin.");

            return self::SUCCESS;
        }

        $password = Str::password(20);

        $user = User::create([
            'name' => $this->option('name') ?: 'Lumi Admin',
            'email' => $email,
            'password' => $password,
        ]);
        $user->forceFill(['role' => Role::Superadmin, 'email_verified_at' => now()])->save();

        $this->info("Superadmin {$email} created.");
        $this->line("Temporary password (shown once, change it after signing in): {$password}");

        return self::SUCCESS;
    }
}
