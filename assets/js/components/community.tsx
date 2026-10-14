import React, { useEffect, useRef, useState } from "react";
import { Plus, X, MessagesSquare } from "lucide-react";
import { request, date, type Question } from "../api";
import { useSite } from "../site";
import { Header, Message, Pagination } from "./common";
import { Comments } from "./comments";
const defaults = [
  "Gleam",
  "Elixir",
  "JavaScript",
  "Python",
  "Tools",
  "Career",
  "Crash Course",
];
export function CommunityPage() {
  const site = useSite();
  const [items, setItems] = useState<Question[]>([]);
  const [search, setSearch] = useState("");
  const [topic, setTopic] = useState("all");
  const [page, setPage] = useState(1);
  const [error, setError] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [asking, setAsking] = useState(false);
  useEffect(() => {
    request<Question[]>("/api/questions")
      .then(setItems)
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));
  }, []);
  const visible = items.filter(
    (q) =>
      (topic === "all" || q.topic === topic) &&
      `${q.title} ${q.body} ${q.name} ${q.topic}`
        .toLocaleLowerCase()
        .includes(search.toLocaleLowerCase()),
  );
  const pages = Math.max(1, Math.ceil(visible.length / 10));
  const topics = [...new Set([...defaults, ...items.map((q) => q.topic)])];
  return (
    <>
      <Header />
      <main className="community-page">
        <div className="community-heading">
          <div>
            <h1>Community</h1>
            <p>မေးခွန်းမေးမယ်။ အတူတူ အဖြေရှာမယ်။</p>
          </div>
          <button
            className="primary-button"
            onClick={() =>
              site.state?.user ? setAsking(true) : site.account()
            }
          >
            <Plus />
            Ask a question
          </button>
        </div>
        <div className="community-tools">
          <input
            type="search"
            aria-label="Search community"
            placeholder="Search questions, topics, developers…"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
          <select
            aria-label="Filter community topic"
            value={topic}
            onChange={(e) => {
              setTopic(e.target.value);
              setPage(1);
            }}
          >
            <option value="all">All topics</option>
            {topics.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </div>
        <Message text={error} />
        {!loaded ? (
          <p role="status">Loading questions…</p>
        ) : visible.length === 0 ? (
          <p className="empty-note">
            No questions yet. Ask something you’re curious about.
          </p>
        ) : (
          <div>
            {visible.slice((page - 1) * 10, page * 10).map((q) => (
              <article className="question-card" key={q.id}>
                <div className="question-card-top">
                  <span className="watch-topic">{q.topic}</span>
                  <span className="question-replies">
                    <MessagesSquare />
                    {q.replies} replies
                  </span>
                </div>
                <h2>
                  <a href={`/community/thread/${q.id}`}>{q.title}</a>
                </h2>
                <p className="question-preview">{q.body}</p>
                <div className="question-meta">
                  <span className="comment-avatar">{q.name[0]}</span>
                  <strong>{q.name}</strong>
                  <time>{date(q.date)}</time>
                </div>
              </article>
            ))}
          </div>
        )}
        <Pagination page={page} pages={pages} setPage={setPage} />
        {asking && <QuestionDialog close={() => setAsking(false)} />}
      </main>
    </>
  );
}
function QuestionDialog({ close }: { close: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    dialog.current?.showModal();
  }, []);
  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const data = Object.fromEntries(new FormData(e.currentTarget)) as Record<
      string,
      string
    >;
    try {
      const result = await request<{ url: string }>(
        "/community/questions",
        data,
      );
      location.assign(result.url);
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }
  return (
    <dialog ref={dialog} className="account-dialog" onCancel={close}>
      <div className="account-dialog-head">
        <h2>Ask the community</h2>
        <button type="button" aria-label="Close question form" onClick={close}>
          <X />
        </button>
      </div>
      <form id="question-form" onSubmit={submit}>
        <label>
          Question title
          <input
            name="title"
            minLength={3}
            maxLength={180}
            required
            placeholder="What are you trying to solve?"
          />
        </label>
        <label>
          Topic
          <input
            name="topic"
            list="question-topics"
            maxLength={60}
            required
            placeholder="Gleam, JavaScript, Career…"
          />
        </label>
        <datalist id="question-topics">
          {defaults.map((t) => (
            <option key={t} value={t} />
          ))}
        </datalist>
        <label>
          Details
          <textarea
            name="body"
            minLength={10}
            maxLength={10000}
            rows={8}
            required
            placeholder="Include what you tried, code and any error message. Myanmar or English welcome."
          />
        </label>
        <small>Public to everyone. Code and line breaks are preserved.</small>
        <Message text={error} />
        <button className="primary-button" disabled={busy}>
          Post question
        </button>
      </form>
    </dialog>
  );
}
export function QuestionPage({ id }: { id: string }) {
  const [q, setQ] = useState<Question | null>(null);
  const [error, setError] = useState("");
  useEffect(() => {
    request<Question>(`/api/questions/${id}`)
      .then(setQ)
      .catch((e) => setError(e.message));
  }, [id]);
  return (
    <>
      <Header />
      <main className="community-page">
        <a className="back-link" href="/community">
          ← Community
        </a>
        <Message text={error} />
        {q ? (
          <>
            <article className="question-detail">
              <p className="watch-topic">{q.topic}</p>
              <h1>{q.title}</h1>
              <div className="question-meta">
                <strong>{q.name}</strong>
                <time>{date(q.date)}</time>
              </div>
              <div className="question-body">{q.body}</div>
            </article>
            <Comments id={id} question />
          </>
        ) : (
          !error && <p role="status">Loading question…</p>
        )}
      </main>
    </>
  );
}
