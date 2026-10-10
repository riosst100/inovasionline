<?php

namespace App\Services;

use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use App\Support\Enums\PostMediaType;
use Illuminate\Http\UploadedFile;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class PostService
{
    private const FEED_WITH = ['user', 'media', 'products.images', 'products.store', 'sharedPost.user', 'sharedPost.media'];

    public function feed(?User $viewer, int $perPage = 15): LengthAwarePaginator
    {
        return Post::query()
            ->whereNull('shared_post_id')
            ->with(self::FEED_WITH)
            ->withCount(['likes', 'comments', 'shares'])
            ->when($viewer, fn ($query) => $query->with(['likes' => fn ($q) => $q->where('user_id', $viewer->id)]))
            ->latest('created_at')
            ->paginate($perPage);
    }

    /**
     * @param  array{body?: string|null, product_ids?: string[], video_duration_seconds?: int|null}  $data
     * @param  UploadedFile[]  $media
     */
    public function create(
        User $author,
        array $data,
        array $media = [],
        ?UploadedFile $video = null,
        ?UploadedFile $videoThumbnail = null,
    ): Post {
        return DB::transaction(function () use ($author, $data, $media, $video, $videoThumbnail) {
            $post = $author->posts()->create([
                'body' => $data['body'] ?? null,
            ]);

            foreach ($media as $index => $file) {
                $path = $file->store('posts', 'public');
                $post->media()->create([
                    'type' => PostMediaType::IMAGE,
                    'path' => $path,
                    'sort_order' => $index,
                ]);
            }

            if ($video !== null) {
                $path = $video->store('posts/videos', 'public');
                $thumbnailPath = $videoThumbnail?->store('posts/video-thumbnails', 'public');

                $post->media()->create([
                    'type' => PostMediaType::VIDEO,
                    'path' => $path,
                    'thumbnail_path' => $thumbnailPath,
                    'duration_seconds' => $data['video_duration_seconds'] ?? null,
                    'sort_order' => 0,
                ]);
            }

            if (! empty($data['product_ids'])) {
                $post->products()->sync($data['product_ids']);
            }

            return $this->loadForResponse($post, $author);
        });
    }

    public function share(User $author, Post $original, ?string $body): Post
    {
        if ($original->shared_post_id !== null) {
            throw new RuntimeException('Cannot share a repost. Share the original post instead.');
        }

        $post = $author->posts()->create([
            'shared_post_id' => $original->id,
            'body' => $body,
        ]);

        return $this->loadForResponse($post, $author);
    }

    public function loadForResponse(Post $post, User $viewer): Post
    {
        return $post->load([
            ...self::FEED_WITH,
            'likes' => fn ($q) => $q->where('user_id', $viewer->id),
        ])->loadCount(['likes', 'comments', 'shares']);
    }

    public function delete(User $requester, Post $post): void
    {
        if ($post->user_id !== $requester->id) {
            throw new RuntimeException('You can only delete your own posts.');
        }

        DB::transaction(function () use ($post) {
            foreach ($post->media as $media) {
                Storage::disk('public')->delete(array_filter([$media->path, $media->thumbnail_path]));
            }
            $post->delete();
        });
    }

    public function toggleLike(User $user, Post $post): bool
    {
        $like = $post->likes()->where('user_id', $user->id)->first();

        if ($like) {
            $like->delete();

            return false;
        }

        $post->likes()->create(['user_id' => $user->id]);

        return true;
    }

    public function comment(User $user, Post $post, string $body): PostComment
    {
        return $post->comments()->create([
            'user_id' => $user->id,
            'body' => $body,
        ])->load('user');
    }

    public function comments(Post $post, int $perPage = 20): LengthAwarePaginator
    {
        return $post->comments()->with('user')->paginate($perPage);
    }

    public function deleteComment(User $requester, PostComment $comment): void
    {
        if ($comment->user_id !== $requester->id && $comment->post->user_id !== $requester->id) {
            throw new RuntimeException('You can only delete your own comments.');
        }

        $comment->delete();
    }
}
