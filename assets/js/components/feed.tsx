import React, { useEffect, useState } from "react";
import { Play, Bookmark, ExternalLink, Search } from "lucide-react";
import { type Post, loadPosts, image, date } from "../api";
import { useSite } from "../site";
import { Header, Sidebar, Message } from "./common";
export function Feed({ savedView = false }: { savedView?: boolean }) {
  const site = useSite();
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [kind, setKind] = useState("all");
  const [topic, setTopic] = useState("all");
  const [open, setOpen] = useState(
    window.matchMedia("(min-width: 761px)").matches,
  );
  useEffect(() => {
    const desktop = window.matchMedia("(min-width: 761px)");
    const resize = () => setOpen(desktop.matches);
    desktop.addEventListener("change", resize);
    return () => desktop.removeEventListener("change", resize);
  }, []);
  function chooseKind(value: string) {
    setKind(value);
    if (window.matchMedia("(max-width: 760px)").matches) setOpen(false);
  }
  function chooseTopic(value: string) {
    setTopic(value);
    if (window.matchMedia("(max-width: 760px)").matches) setOpen(false);
  }
  useEffect(() => {
    loadPosts()
      .then(setPosts)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);
  const topics = [
    ...new Set(["Crash Course", ...posts.map((p) => p.category)]),
  ];
  const visible = posts.filter(
    (p) =>
      (!savedView || site.saved.includes(p.id)) &&
      (kind === "all" || p.kind === kind) &&
      (topic === "all" || p.category === topic) &&
      `${p.title} ${p.excerpt} ${p.category} ${p.creator}`
        .normalize()
        .toLocaleLowerCase()
        .includes(search.normalize().toLocaleLowerCase()),
  );
  return (
    <div className={`${open ? "mobile-sidebar-open" : "sidebar-hidden"}`}>
      <Header
        search={search}
        setSearch={setSearch}
        toggle={() => setOpen(!open)}
      />
      <Sidebar
        kind={kind}
        setKind={chooseKind}
        topics={topics}
        topic={topic}
        setTopic={chooseTopic}
        saved={savedView}
      />
      <main className="feed-main">
        {savedView && (
          <div className="saved-heading">
            <h1>Saved posts</h1>
            <p>
              {site.state?.user
                ? "Your private reading list."
                : "Sign in to see your saved articles and videos."}
            </p>
            {!site.state?.user && (
              <button className="primary-button" onClick={site.account}>
                Sign in
              </button>
            )}
          </div>
        )}
        <div className="topic-chips" aria-label="Filter by topic">
          {["all", ...topics].map((t) => (
            <button
              className={`filter ${t === topic ? "active" : ""}`}
              key={t}
              aria-pressed={t === topic}
              onClick={() => setTopic(t)}
            >
              {t === "all" ? "All" : t}
            </button>
          ))}
        </div>
        <Message text={error} />
        {loading ? (
          <p role="status">Loading posts…</p>
        ) : (
          <div className="feed-grid">
            {visible.map((post) => (
              <PostCard key={post.id} post={post} />
            ))}
          </div>
        )}
        {!loading && !error && visible.length === 0 && (
          <div className="empty-results" role="status">
            <Search />
            <h2>{savedView ? "No saved posts yet" : "No matching posts"}</h2>
            <p>တခြား keyword နဲ့ ရှာကြည့်ပါ။</p>
            <button
              onClick={() => {
                setSearch("");
                setKind("all");
                setTopic("all");
              }}
            >
              Clear filters
            </button>
          </div>
        )}
      </main>
    </div>
  );
}
function PostCard({ post }: { post: Post }) {
  const site = useSite();
  const src = image(post);
  const saved = site.saved.includes(post.id);
  return (
    <article className="feed-card">
      <a
        className="feed-thumbnail"
        href={`/posts/${post.id}`}
        data-topic={post.category}
        tabIndex={-1}
        aria-hidden="true"
      >
        {src ? (
          <img src={src} alt="" loading="lazy" />
        ) : (
          <div className="generated-thumbnail">
            <span className="thumbnail-topic">{post.category}</span>
            <span className="thumbnail-code">
              {post.category === "Tools" ? "git" : "</>"}
              <small>{post.category}</small>
            </span>
            <span className="thumbnail-brand">SourceCat / Myanmar</span>
          </div>
        )}
        <span className="thumbnail-type">
          {post.kind === "video" ? (
            <>
              <Play />
              Video
            </>
          ) : (
            post.minutes
          )}
        </span>
      </a>
      <div className="feed-card-info">
        <span
          className={`channel-avatar ${post.kind === "video" ? "video-avatar" : ""}`}
        >
          {post.kind === "video" ? (
            <Play />
          ) : (
            <img
              className="sourcecat-mark"
              src="/images/sourcecat-solid.png"
              alt=""
            />
          )}
        </span>
        <div>
          <h2>
            <a href={`/posts/${post.id}`}>{post.title}</a>
          </h2>
          <p className="channel-name">{post.creator}</p>
          <p className="content-meta">
            {post.category} <span>·</span> {date(post.date)}
          </p>
        </div>
        <div className="card-actions">
          <button
            className="bookmark-button compact"
            aria-label={`${saved ? "Unsave" : "Save"} ${post.title}`}
            aria-pressed={saved}
            onClick={() => void site.save(post.id)}
          >
            <Bookmark fill={saved ? "currentColor" : "none"} />
          </button>
          <button
            className="card-more"
            aria-label={`Copy link to ${post.title}`}
            onClick={() => {
              navigator.clipboard
                .writeText(`${location.origin}/posts/${post.id}`)
                .then(() => site.notify("Link copied."))
                .catch(() => site.notify("Could not copy the link."));
            }}
          >
            <ExternalLink />
          </button>
        </div>
      </div>
    </article>
  );
}
