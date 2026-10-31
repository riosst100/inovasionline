<?php

namespace App\Services;

use App\Support\ImageOptimizer;
use App\Models\CommunityRole;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\User;
use App\Support\Enums\PostMediaType;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\UploadedFile;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class PostService
{
    private const FEED_WITH = [
        'user.regionAdmins', 'media', 'products.images', 'sharedPost.user.regionAdmins', 'sharedPost.media',
    ];

    public const TAB_OFFICIAL = 'official';

    public const TAB_PUBLIC = 'public';

    /** Unread first (the app sends which ones it hasn't shown), then newest. */
    public const SORT_RELEVANCE = 'relevance';

    public const SORT_NEWEST = 'newest';

    public const SORT_OLDEST = 'oldest';

    /**
     * @param  string|null  $tab  official (only authors with a verified badge), public (everyone) or null (same as public)
     * @param  array<string, string>  $region  Post::REGION_COLUMNS => code; only the narrowest level is applied
     * @param  string[]  $unreadIds  for SORT_RELEVANCE: posts the app hasn't shown yet (at most UNREAD_LIMIT)
     */
    public function feed(
        ?User $viewer,
        int $perPage = 15,
        ?string $tab = null,
        array $region = [],
        string $sort = self::SORT_NEWEST,
        array $unreadIds = [],
    ): LengthAwarePaginator {
        $direction = $sort === self::SORT_OLDEST ? 'asc' : 'desc';

        return $this->feedQuery($tab, $region)
            ->with(self::FEED_WITH)
            ->withCount(['likes', 'comments', 'shares'])
            ->when($viewer, fn ($query) => $query->with(['likes' => fn ($q) => $q->where('user_id', $viewer->id)]))
            ->when($sort === self::SORT_RELEVANCE && $unreadIds !== [], fn ($query) => $query->orderByRaw(
                'case when posts.id in ('.implode(',', array_fill(0, count($unreadIds), '?')).') then 0 else 1 end',
                array_values($unreadIds),
            ))
            ->orderBy('created_at', $direction)
            // Same-second posts keep one order across pages.
            ->orderBy('id', $direction)
            ->paginate($perPage);
    }

    /** Only this many of each tab's newest posts can count as unread; older ones never do. */
    public const UNREAD_LIMIT = 100;

    /**
     * Ids of each tab's newest posts, for the unread badges: the app counts the ones it hasn't shown yet.
     * The viewer's own posts are left out, and Publik follows the same region filter as its feed.
     *
     * @param  array<string, string>  $region
     * @return array{official: string[], public: string[]}
     */
    public function recentIds(?User $viewer, array $region = []): array
    {
        $ids = fn (string $tab, array $region) => $this->feedQuery($tab, $region)
            ->when($viewer, fn ($query) => $query->where('user_id', '!=', $viewer->id))
            ->latest('created_at')
            ->limit(self::UNREAD_LIMIT)
            ->pluck('id')
            ->all();

        return [
            self::TAB_OFFICIAL => $ids(self::TAB_OFFICIAL, []),
            self::TAB_PUBLIC => $ids(self::TAB_PUBLIC, $region),
        ];
    }

    private function feedQuery(?string $tab, array $region): Builder
    {
        $narrowest = collect(Post::REGION_COLUMNS)->reverse()->first(fn ($column) => filled($region[$column] ?? null));

        return Post::query()
            ->whereNull('shared_post_id')
            ->when($tab === self::TAB_OFFICIAL, fn ($query) => $query->whereHas('user', fn ($q) => $q->whereNotNull('verified_badge_at')))
            ->when($narrowest, fn ($query) => $query->where($narrowest, $region[$narrowest]));
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
                ...$author->only(Post::REGION_COLUMNS),
            ]);

            foreach ($media as $index => $file) {
                $path = ImageOptimizer::store($file, 'posts');
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
            ...$author->only(Post::REGION_COLUMNS),
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

    /** The author, or someone appointed to the post's region whose role may delete posts. */
    public function canModerate(?User $user, Post $post): bool
    {
        return $user !== null && ($post->user_id === $user->id
            || $user->canInRegion(CommunityRole::DELETE_POSTS, $post->regionCodes()));
    }

    public function delete(User $requester, Post $post): void
    {
        if (! $this->canModerate($requester, $post)) {
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
        ])->load('user.regionAdmins')->setRelation('post', $post);
    }

    public function comments(Post $post, int $perPage = 20): LengthAwarePaginator
    {
        $paginator = $post->comments()->with('user.regionAdmins')->paginate($perPage);
        // The resource reads the post for its region (badge, moderation).
        $paginator->getCollection()->each(fn (PostComment $comment) => $comment->setRelation('post', $post));

        return $paginator;
    }

    /** The commenter, the post's author, or someone appointed to the post's region whose role may delete comments. */
    public function canDeleteComment(?User $user, PostComment $comment): bool
    {
        return $user !== null && ($comment->user_id === $user->id
            || $comment->post->user_id === $user->id
            || $user->canInRegion(CommunityRole::DELETE_COMMENTS, $comment->post->regionCodes()));
    }

    public function deleteComment(User $requester, PostComment $comment): void
    {
        if (! $this->canDeleteComment($requester, $comment)) {
            throw new RuntimeException('You can only delete your own comments.');
        }

        $comment->delete();
    }
}
