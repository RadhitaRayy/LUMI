<?php

namespace App\Enums;

enum Role: string
{
    /** Owner/developer of Lumi: full access to Lumi Console. */
    case Superadmin = 'superadmin';

    /** Anyone who signs up from the app. */
    case User = 'user';
}
