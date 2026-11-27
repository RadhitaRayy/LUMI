<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\PersonaUpdated;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserPersona;
use App\Services\Agent\PromptAssembler;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PersonaController extends Controller
{
    public function __construct(
        private readonly PromptAssembler $prompts,
    ) {}

    public function show(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $persona = $user->persona;

        return response()->json([
            'persona' => $persona ? $persona->toApiArray() : UserPersona::defaultApiArray(),
            'presets' => $this->prompts->presetCatalog(),
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $data = $request->validate([
            'preset' => ['required', 'string', Rule::in(UserPersona::PRESETS)],
            'call_me' => ['nullable', 'string', 'max:'.UserPersona::MAX_CALL_ME_LENGTH],
            'custom_instructions' => ['nullable', 'string', 'max:'.UserPersona::MAX_CUSTOM_INSTRUCTIONS_LENGTH],
            'is_active' => ['required', 'boolean'],
        ]);

        $callMe = isset($data['call_me']) ? trim((string) $data['call_me']) : null;
        $custom = isset($data['custom_instructions']) ? trim((string) $data['custom_instructions']) : null;

        /** @var UserPersona $persona */
        $persona = $user->persona()->updateOrCreate(
            ['user_id' => $user->id],
            [
                'preset' => $data['preset'],
                'call_me' => $callMe !== '' ? $callMe : null,
                'custom_instructions' => $custom !== '' ? $custom : null,
                'is_active' => (bool) $data['is_active'],
            ],
        );

        broadcast(PersonaUpdated::for($persona))->toOthers();

        return response()->json([
            'persona' => $persona->toApiArray(),
            'presets' => $this->prompts->presetCatalog(),
        ]);
    }
}
