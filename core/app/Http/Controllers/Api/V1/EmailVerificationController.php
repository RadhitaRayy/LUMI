<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AuthCodePurpose;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Services\Auth\AuthCodeService;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EmailVerificationController extends Controller
{
    public function __construct(private readonly AuthCodeService $codes) {}

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'digits:6'],
        ]);

        $user = $request->user();

        if (! $user->hasVerifiedEmail()) {
            $this->codes->consume($user, AuthCodePurpose::VerifyEmail, $data['code']);
            $user->markEmailAsVerified();
            event(new Verified($user));
        }

        return response()->json(['user' => new UserResource($user->refresh())]);
    }

    public function resend(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->hasVerifiedEmail()) {
            $this->codes->send($user, AuthCodePurpose::VerifyEmail);
        }

        return response()->json(['message' => __('A new verification code has been sent to your email.')]);
    }
}
