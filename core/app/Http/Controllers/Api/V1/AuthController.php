<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AuthCodePurpose;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\AppSetting;
use App\Models\User;
use App\Services\Auth\AuthCodeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class AuthController extends Controller
{
    public function __construct(private readonly AuthCodeService $codes) {}

    public function register(Request $request): JsonResponse
    {
        if (! AppSetting::current()->registration_open) {
            throw new ApiException('registration_closed', 'Pendaftaran sedang ditutup.', 403);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'string', 'lowercase', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::defaults(), 'min:8'],
            'device_name' => ['required', 'string', 'max:100'],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
        ]);

        $this->codes->send($user, AuthCodePurpose::VerifyEmail);

        return response()->json([
            'user' => new UserResource($user->refresh()),
            'token' => $user->createToken($data['device_name'])->plainTextToken,
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['required', 'string', 'max:100'],
        ]);

        $user = User::where('email', strtolower($data['email']))->first();

        if ($user === null || ! Hash::check($data['password'], $user->password)) {
            throw new ApiException('invalid_credentials', 'Email atau password salah.', 401);
        }

        if ($user->is_blocked) {
            throw new ApiException('account_blocked', 'Akun kamu diblokir. Hubungi admin Lumi.', 403);
        }

        return response()->json([
            'user' => new UserResource($user),
            'token' => $user->createToken($data['device_name'])->plainTextToken,
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Kamu sudah keluar dari perangkat ini.']);
    }
}
