import sys
import time
import instaloader
from pathlib import Path

HEADERS = {
    "X-IG-App-ID": "936619743392459",
    "X-ASBD-ID": "198387",
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    ),
    "X-Requested-With": "XMLHttpRequest",
}

def iter_profile_posts_v1(L, profile):
    max_id = None
    headers = {
        **HEADERS,
        "Referer": f"https://www.instagram.com/{profile.username}/"
    }

    url = f"https://www.instagram.com/api/v1/feed/user/{profile.userid}/"

    while True:
        params = {"count": 12}
        if max_id:
            params["max_id"] = max_id

        response = L.context._session.get(
            url,
            headers=headers,
            params=params,
            timeout=L.context.request_timeout
        )
        response.raise_for_status()

        data = response.json()

        for item in data.get("items") or []:
            yield instaloader.Post.from_iphone_struct(L.context, item)

        if not data.get("more_available"):
            break

        max_id = data.get("next_max_id")
        if not max_id:
            break

        time.sleep(2)

def main():
    if len(sys.argv) < 4:
        print("Usage: python insta_fallback.py <profile> <login_user> <download_dir>")
        sys.exit(1)

    target_profile = sys.argv[1]
    login_user = sys.argv[2]
    download_dir = Path(sys.argv[3])

    L = instaloader.Instaloader(
        dirname_pattern=str(download_dir / "{profile}"),
        download_videos=True,
        download_video_thumbnails=False,
        download_geotags=False,
        download_comments=False,
        save_metadata=True,
        compress_json=False,
        post_metadata_txt_pattern=""
    )

    print(f"Loading session for: {login_user}")
    L.load_session_from_file(login_user)

    print(f"Fetching profile: {target_profile}")
    profile = instaloader.Profile.from_username(L.context, target_profile)

    print(f"Using fallback endpoint for user ID: {profile.userid}")

    count = 0

    for post in iter_profile_posts_v1(L, profile):
        try:
            L.download_post(post, target=profile.username)
            count += 1
            print(f"Downloaded post #{count}: {post.shortcode}")
        except Exception as e:
            print(f"Skipped post {getattr(post, 'shortcode', 'unknown')}: {e}")

    print(f"Fallback complete. Total processed: {count}")

if __name__ == "__main__":
    main()