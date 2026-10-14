import React, { useEffect, useState, useRef } from "react";
import { MessageSquare, X, Trash2, Reply } from "lucide-react";
import { request, date, type Comment, type Conversation } from "../api";
import { useSite } from "../site";
import { Message, Pagination } from "./common";
export function Comments({
  id,
  question = false,
}: {
  id: string;
  question?: boolean;
}) {
  const site = useSite();
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Conversation | null>(null);
  const [body, setBody] = useState("");
  const [parent, setParent] = useState<Comment | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [remove, setRemove] = useState<Comment | null>(null);
  const confirmRef = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    if (remove && !confirmRef.current?.open) confirmRef.current?.showModal();
  }, [remove]);
  const path = `/community/${question ? "questions" : "posts"}/${id}/comments`;
  const load = () => request<Conversation>(`${path}/${page}`).then(setData);
  useEffect(() => {
    load().catch((e) => setError(e.message));
  }, [path, page, site.state?.user?.name, site.state?.admin]);
  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!site.state?.user && !site.state?.admin) {
      site.account();
      return;
    }
    setBusy(true);
    setError("");
    try {
      await request(path, { body, parent: parent?.id || "" });
      setBody("");
      setParent(null);
      if (page !== 1) setPage(1);
      else await load();
      site.notify("Comment posted.");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function deleteComment() {
    if (!remove) return;
    setBusy(true);
    try {
      await request(`/community/comments/${remove.id}/delete`, {});
      setRemove(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  function render(c: Comment, child = false) {
    const replyTo = c.parent
      ? data?.comments.find((p) => p.id === c.parent)
      : null;
    return (
      <article
        key={c.id}
        className={`comment-item ${child ? "comment-reply" : ""}`}
      >
        <div className="comment-avatar">{c.name[0]}</div>
        <div className="comment-content">
          <div className="comment-meta">
            <strong>{c.name}</strong>
            {c.role === "author" && (
              <span className="author-badge">Author</span>
            )}
            <time>{date(c.date)}</time>
          </div>
          {replyTo && child && (
            <small className="reply-to">Replying to {replyTo.name}</small>
          )}
          <p
            className={
              c.deleted ? "comment-text comment-deleted" : "comment-text"
            }
          >
            {c.deleted ? "Comment removed" : c.body}
          </p>
          <div className="comment-actions">
            {!c.deleted && (
              <button
                type="button"
                onClick={() => {
                  if (!site.state?.user && !site.state?.admin) {
                    site.account();
                    return;
                  }
                  setParent(c);
                  document.getElementById("comment-body")?.focus();
                }}
              >
                <Reply /> Reply
              </button>
            )}
            {c.can_delete && (
              <button type="button" onClick={() => setRemove(c)}>
                <Trash2 /> Delete
              </button>
            )}
          </div>
        </div>
      </article>
    );
  }
  const roots = data?.comments.filter((c) => !c.parent) || [];
  return (
    <div className="post-comments">
      <div className="comments-heading">
        <h2>
          <MessageSquare /> Conversation <span>{data?.total || 0}</span>
        </h2>
        <span>မေးမယ်။ ဆွေးနွေးမယ်။ မျှဝေမယ်။</span>
      </div>
      <p>
        {site.state?.user
          ? `Commenting as ${site.state.user.name}`
          : site.state?.admin
            ? "Replying as the author"
            : "Guests can read every conversation."}
      </p>
      <form id="comment-form" onSubmit={submit}>
        {parent && (
          <div className="reply-target">
            <span>Replying to {parent.name}</span>
            <button type="button" onClick={() => setParent(null)}>
              <X />
              Cancel reply
            </button>
          </div>
        )}
        <label className="sr-only" htmlFor="comment-body">
          Your comment
        </label>
        <textarea
          id="comment-body"
          rows={3}
          maxLength={2000}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          required
          placeholder="Share a thought or ask a question…"
        />
        <div className="comment-compose-actions">
          <small>Be kind. Keep it helpful.</small>
          <button
            className="primary-button"
            disabled={busy}
            type={site.state?.user || site.state?.admin ? "submit" : "button"}
            onClick={() => {
              if (!site.state?.user && !site.state?.admin) site.account();
            }}
          >
            {site.state?.user || site.state?.admin
              ? "Comment"
              : "Sign in to comment"}
          </button>
        </div>
      </form>
      <Message text={error} />
      {!data ? (
        <p role="status">Loading conversation…</p>
      ) : roots.length === 0 ? (
        <p className="empty-note">Be the first to start the conversation.</p>
      ) : (
        <div id="comment-list">
          {roots.map((root) => (
            <div className="comment-thread" key={root.id}>
              {render(root)}
              {data.comments
                .filter((c) => c.root === root.id && c.parent)
                .map((c) => render(c, true))}
            </div>
          ))}
        </div>
      )}
      {data && data.pages > 1 && (
        <Pagination page={page} pages={data.pages} setPage={setPage} />
      )}{" "}
      {remove && (
        <dialog
          ref={confirmRef}
          className="confirm-card"
          aria-label="Delete comment"
          onCancel={() => setRemove(null)}
        >
          <h2>Delete this comment?</h2>
          <p>Replies will stay visible.</p>
          <button
            disabled={busy}
            onClick={deleteComment}
            className="danger-button"
          >
            Delete comment
          </button>
          <button onClick={() => setRemove(null)} className="secondary-button">
            Cancel
          </button>
        </dialog>
      )}
    </div>
  );
}
