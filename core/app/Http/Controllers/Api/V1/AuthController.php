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
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AuthController extends Controller
{
    public function __construct(private readonly AuthCodeService $codes) {}

    public function register(Request $request): JsonResponse
    {
        if (! AppSetting::current()->registration_open) {
            throw new ApiException('registration_closed', __('Registration is closed right now.'), 403);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'string', 'lowercase', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::defaults(), 'min:8'],
            'device_name' => ['required', 'string', 'max:100'],
            'locale' => ['nullable', 'string', Rule::in(config('app.supported_locales'))],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
            // The app sends its language; otherwise keep the one this request is answered in.
            'locale' => $data['locale'] ?? app()->getLocale(),
        ]);

        $this->codes->send($user, AuthCodePurpose::VerifyEmail);

        return response()->json([
            'user' => new UserResource($user->refresh()),
            ...$this->issueToken($user, $data['device_name']),
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
            throw new ApiException('invalid_credentials', __('Wrong email or password.'), 401);
        }

        if ($user->is_blocked) {
            throw new ApiException('account_blocked', __('Your account is blocked. Contact the Lumi admin.'), 403);
        }

        return response()->json([
            'user' => new UserResource($user),
            ...$this->issueToken($user, $data['device_name']),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => __('You are signed out of this device.')]);
    }

    /**
     * A new device token. `token_id` lets the device recognise its own `session.revoked` event.
     *
     * @return array{token: string, token_id: int}
     */
    private function issueToken(User $user, string $deviceName): array
    {
        $token = $user->createToken($deviceName);

        return ['token' => $token->plainTextToken, 'token_id' => (int) $token->accessToken->getKey()];
    }
}
