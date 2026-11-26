<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\SessionRevoked;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class MeController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json(['user' => new UserResource($request->user())]);
    }

    public function update(Request $request): JsonResponse
    {
        // Either field may be sent alone: the app changes the language without touching the name.
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:60'],
            'locale' => ['sometimes', 'required', 'string', Rule::in(config('app.supported_locales'))],
        ]);

        $user = $request->user();
        $user->update($data);

        return response()->json(['user' => new UserResource($user)]);
    }

    public function updatePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string', 'current_password:sanctum'],
            'password' => ['required', 'string', Password::defaults(), 'min:8', 'different:current_password'],
        ]);

        $user = $request->user();
        $user->forceFill(['password' => $data['password']])->save();

        // Keep this device signed in, sign out the others.
        $others = $user->tokens()->whereKeyNot($user->currentAccessToken()->getKey());
        $revoked = $others->pluck('id')->all();
        $others->delete();
        if ($revoked !== []) {
            broadcast(SessionRevoked::for($user->id, $revoked));
        }

        return response()->json(['message' => __('Password changed. Your other devices have been signed out.')]);
    }
}
