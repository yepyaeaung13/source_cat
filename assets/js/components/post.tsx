import React, { useEffect, useState } from "react";
import { ArrowLeft, Play, Bookmark, ExternalLink } from "lucide-react";
import { loadPost, date, type Post } from "../api";
import { useSite } from "../site";
import { Header, Message } from "./common";
import { Comments } from "./comments";
export function PostPage({ id }: { id: string }) {
  const site = useSite();
  const [post, setPost] = useState<Post | null>(null);
  const [playing, setPlaying] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    loadPost(id)
      .then(setPost)
      .catch((e) => setError(e.message));
  }, [id]);
  const saved = site.saved.includes(id);
  return (
    <>
      <Header />
      <main className="watch-page">
        <a className="back-link" href="/">
          <ArrowLeft />
          All posts
        </a>
        <Message text={error} />
        {!post && !error ? (
          <p role="status">Loading post…</p>
        ) : (
          post && (
            <>
              {post.kind === "video" ? (
                <div className="watch-video">
                  {playing ? (
                    <iframe
                      src={`https://www.youtube-nocookie.com/embed/${post.youtube}?autoplay=1`}
                      title={post.title}
                      allow="autoplay; encrypted-media; picture-in-picture"
                      allowFullScreen
                      referrerPolicy="strict-origin-when-cross-origin"
                    />
                  ) : (
                    <>
                      <img
                        src={`https://i.ytimg.com/vi/${post.youtube}/hqdefault.jpg`}
                        alt={post.title}
                      />
                      <button
                        className="play-button"
                        onClick={() => setPlaying(true)}
                        aria-label={`Play ${post.title}`}
                      >
                        <Play />
                      </button>
                    </>
                  )}
                </div>
              ) : (
                post.thumbnail && (
                  <div className="article-cover">
                    <img src={post.thumbnail} alt={post.title} />
                  </div>
                )
              )}
              <p className="watch-topic">
                {post.category} <span>·</span> {post.minutes}
              </p>
              <h1>{post.title}</h1>
              <div className="watch-author">
                <span className="channel-avatar">
                  <img
                    className="sourcecat-mark"
                    src="/images/sourcecat-solid.png"
                    alt=""
                  />
                </span>
                <div>
                  <strong>{post.creator}</strong>
                  <p>{date(post.date)}</p>
                </div>
                <button
                  className="bookmark-button"
                  aria-pressed={saved}
                  onClick={() => void site.save(id)}
                >
                  <Bookmark fill={saved ? "currentColor" : "none"} />
                  {saved ? "Saved" : "Save"}
                </button>
                <button
                  className="share-button"
                  onClick={() => {
                    const canShare = typeof navigator.share === "function";
                    const action = canShare
                      ? navigator.share({
                          title: post.title,
                          url: location.href,
                        })
                      : navigator.clipboard.writeText(location.href);
                    action
                      .then(() =>
                        site.notify(canShare ? "Shared." : "Link copied."),
                      )
                      .catch(() =>
                        site.notify("Sharing cancelled or unavailable."),
                      );
                  }}
                >
                  <ExternalLink /> Share
                </button>
                {post.kind === "video" && (
                  <a
                    className="youtube-link"
                    href={`https://www.youtube.com/watch?v=${post.youtube}`}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Watch on YouTube <ExternalLink />
                  </a>
                )}
              </div>
              <p className="watch-description">{post.excerpt}</p>
              <div
                className="prose"
                dangerouslySetInnerHTML={{ __html: post.body }}
              />
              <Comments id={id} />
            </>
          )
        )}
      </main>
    </>
  );
}
