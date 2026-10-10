<?php

namespace App\Support\Enums;

enum ChatThreadType: string
{
    case GLOBAL = 'global';
    case REGION = 'region';
    case DM = 'dm';
    case OFFICIAL = 'official';
}
