<?php

namespace App\Support\Enums;

enum PhotoStatus: string
{
    case PROCESSING = 'processing';
    case PUBLISHED = 'published';
    case ARCHIVED = 'archived';
}
