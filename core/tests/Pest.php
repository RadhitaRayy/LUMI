<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
| Pest configuration. The starter kit's class-based tests keep their own setup;
| the Lumi API tests under tests/Feature/Api use these defaults.
*/

pest()->extend(TestCase::class)
    ->use(RefreshDatabase::class)
    ->in('Feature/Api', 'Feature/Console');
