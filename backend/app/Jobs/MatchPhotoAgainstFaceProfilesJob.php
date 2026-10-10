<?php

namespace App\Jobs;

use App\Models\Photo;
use App\Services\PhotoMatchService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class MatchPhotoAgainstFaceProfilesJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public readonly Photo $photo) {}

    public function handle(PhotoMatchService $photoMatchService): void
    {
        $photoMatchService->matchPhotoAgainstAllUsers($this->photo);
    }
}
