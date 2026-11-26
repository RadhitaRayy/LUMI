<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AuthCodePurpose;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Auth\AuthCodeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password;

class PasswordResetController extends Controller
{
    public function __construct(private readonly AuthCodeService $codes) {}

    public function forgot(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if ($user !== null && ! $user->is_blocked) {
            $this->codes->send($user, AuthCodePurpose::ResetPassword);
        }

        // Same answer whether or not the email exists, so accounts can't be discovered.
        return response()->json([
            'message' => 'Kalau email itu terdaftar, kode reset sudah dikirim.',
        ]);
    }

    public function reset(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'code' => ['required', 'string', 'digits:6'],
            'password' => ['required', 'string', Password::defaults(), 'min:8'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if ($user === null || $user->is_blocked) {
            throw new ApiException('code_invalid', 'Kode tidak valid. Minta kode baru.', 422);
        }

        $this->codes->consume($user, AuthCodePurpose::ResetPassword, $data['code']);

        $user->forceFill(['password' => $data['password']])->save();

        // A password reset signs out every device.
        $user->tokens()->delete();

        return response()->json([
            'message' => 'Password sudah diganti. Silakan masuk lagi di semua perangkat.',
        ]);
    }
}
