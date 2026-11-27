<?php

it('returns ok on the public health endpoint without authentication', function () {
    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertJsonPath('status', 'ok')
        ->assertJsonPath('app', 'Lumi Core')
        ->assertJsonStructure(['status', 'app', 'time']);
});
