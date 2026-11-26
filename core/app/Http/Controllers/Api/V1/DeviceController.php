<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\SessionRevoked;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Each signed-in device is one Sanctum token.
 */
class DeviceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $currentId = $user->currentAccessToken()->getKey();

        $devices = $user->tokens()
            ->orderByDesc('last_used_at')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (PersonalAccessToken $token) => [
                'id' => $token->id,
                'name' => $token->name,
                'last_used_at' => $token->last_used_at?->toIso8601String(),
                'created_at' => $token->created_at?->toIso8601String(),
                'is_current' => $token->id === $currentId,
            ]);

        return response()->json(['devices' => $devices]);
    }

    public function destroy(Request $request, int $device): JsonResponse
    {
        $token = $request->user()->tokens()->findOrFail($device);
        $token->delete();
        broadcast(SessionRevoked::for($request->user()->id, [$token->getKey()]));

        return response()->json(['message' => __('Device signed out.')]);
    }
}
