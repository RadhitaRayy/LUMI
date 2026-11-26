<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use App\Http\Requests\Settings\ProfileUpdateRequest;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;
use Inertia\Response;

/**
 * The owner's own profile in Lumi Console. There is no "delete account" here: removing the only
 * superadmin would lock everyone out of the Console.
 */
class ProfileController extends Controller
{
    public function edit(): Response
    {
        return Inertia::render('settings/profile');
    }

    public function update(ProfileUpdateRequest $request): RedirectResponse
    {
        $request->user()->fill($request->validated())->save();

        Inertia::flash('toast', ['type' => 'success', 'message' => 'Profil disimpan.']);

        return to_route('profile.edit');
    }
}
