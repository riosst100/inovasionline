<?php

namespace App\Services;

use App\Jobs\GeneratePhotoEmbeddingsJob;
use App\Jobs\MatchPhotoAgainstFaceProfilesJob;
use App\Jobs\MatchSelfieAgainstPhotosJob;
use App\Models\Photo;
use App\Models\Photographer;
use App\Models\PhotoMatch;
use App\Models\User;
use App\Models\UserFaceProfile;
use App\Support\Enums\PhotoStatus;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class PhotoMatchService
{
    public function __construct(private readonly FaceMatchService $faceMatchService) {}

    public function uploadSelfie(User $user, UploadedFile $file): UserFaceProfile
    {
        $path = $file->store('selfies', 'public');

        $profile = UserFaceProfile::updateOrCreate(
            ['user_id' => $user->id],
            ['selfie_path' => $path, 'embedding' => null, 'status' => 'pending'],
        );

        // A re-uploaded selfie invalidates previously computed matches, which
        // were based on the old face — regenerate from scratch rather than
        // leaving stale matches mixed in with new ones.
        PhotoMatch::where('user_id', $user->id)->delete();

        MatchSelfieAgainstPhotosJob::dispatch($profile);

        return $profile;
    }

    public function uploadPhoto(Photographer $photographer, UploadedFile $file, array $meta): Photo
    {
        $path = $file->store('photos', 'public');
        $watermarkedPath = $this->generateWatermark($path);

        $photo = Photo::create([
            'photographer_id' => $photographer->id,
            'photo_event_id' => $meta['photo_event_id'] ?? null,
            'path' => $path,
            'watermarked_path' => $watermarkedPath,
            'price' => $meta['price'] ?? 0,
            'status' => PhotoStatus::PROCESSING,
        ]);

        GeneratePhotoEmbeddingsJob::dispatch($photo);

        return $photo;
    }

    public function matchUserAgainstAllPhotos(UserFaceProfile $profile): void
    {
        $probeEmbedding = $profile->embedding;
        if (! $probeEmbedding) {
            return;
        }

        Photo::query()
            ->where('status', PhotoStatus::PUBLISHED)
            ->whereNotNull('embeddings')
            ->select(['id', 'embeddings'])
            ->chunkById(300, function ($photos) use ($profile, $probeEmbedding) {
                $candidates = [];
                foreach ($photos as $photo) {
                    foreach ($photo->embeddings ?? [] as $index => $face) {
                        $candidates[] = [
                            'id' => "{$photo->id}:{$index}",
                            'embedding' => $face['embedding'],
                        ];
                    }
                }

                if (empty($candidates)) {
                    return;
                }

                $matches = $this->faceMatchService->compare($probeEmbedding, $candidates);
                $this->persistMatches($profile->user_id, $matches);
            });
    }

    public function matchPhotoAgainstAllUsers(Photo $photo): void
    {
        $faces = $photo->embeddings ?? [];
        if (empty($faces)) {
            return;
        }

        UserFaceProfile::query()
            ->where('status', 'ready')
            ->whereNotNull('embedding')
            ->select(['user_id', 'embedding'])
            ->chunkById(300, function ($profiles) use ($photo, $faces) {
                $candidates = $profiles->map(fn ($profile) => [
                    'id' => $profile->user_id,
                    'embedding' => $profile->embedding,
                ])->all();

                foreach ($faces as $index => $face) {
                    $matches = $this->faceMatchService->compare($face['embedding'], $candidates);

                    foreach ($matches as $match) {
                        PhotoMatch::updateOrCreate(
                            [
                                'user_id' => $match['id'],
                                'photo_id' => $photo->id,
                                'matched_face_index' => $index,
                            ],
                            ['confidence_score' => $match['score']],
                        );
                    }
                }
            }, 'user_id');
    }

    private function persistMatches(string $userId, array $matches): void
    {
        foreach ($matches as $match) {
            [$photoId, $faceIndex] = explode(':', $match['id']);

            PhotoMatch::updateOrCreate(
                [
                    'user_id' => $userId,
                    'photo_id' => $photoId,
                    'matched_face_index' => (int) $faceIndex,
                ],
                ['confidence_score' => $match['score']],
            );
        }
    }

    private function generateWatermark(string $originalPath): string
    {
        $manager = new \Intervention\Image\ImageManager(new \Intervention\Image\Drivers\Gd\Driver());

        $image = $manager->read(Storage::disk('public')->path($originalPath));

        $image->text('PREVIEW • PotoCandid', $image->width() / 2, $image->height() / 2, function ($font) {
            $font->size(48);
            $font->color('rgba(255, 255, 255, 0.55)');
            $font->align('center');
            $font->valign('middle');
            $font->angle(-30);
        });

        $watermarkedPath = preg_replace('/(\.[a-zA-Z0-9]+)$/', '-watermarked$1', $originalPath);
        Storage::disk('public')->put($watermarkedPath, (string) $image->encode());

        return $watermarkedPath;
    }
}
