import { listPosts, getPost, buildCSRFHeaders } from "./ash_rpc";

export type Post = {
  id: string;
  kind: string;
  title: string;
  category: string;
  excerpt: string;
  body: string;
  youtube: string;
  creator: string;
  thumbnail: string;
  status: string;
  date: string;
  minutes: string;
};
export type AccountState = {
  token: string;
  suggestion: string;
  user: { name: string; kind: "pin" } | null;
  admin: boolean;
};
export type Question = {
  id: string;
  name: string;
  title: string;
  topic: string;
  body: string;
  date: string;
  replies: number;
};
export type Comment = {
  id: string;
  name: string;
  role: string;
  parent: string;
  root: string;
  body: string;
  date: string;
  deleted: boolean;
  can_delete: boolean;
};
export type Conversation = {
  comments: Comment[];
  page: number;
  pages: number;
  roots: number;
  total: number;
};
let csrf =
  document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ||
  "";
export function setCsrf(token: string) {
  csrf = token;
}
export async function request<T>(
  path: string,
  fields?: Record<string, string>,
): Promise<T> {
  const response = await fetch(path, {
    method: fields ? "POST" : "GET",
    credentials: "same-origin",
    headers: fields
      ? {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrf,
          Accept: "application/json",
        }
      : { Accept: "application/json" },
    body: fields ? JSON.stringify(fields) : undefined,
  });
  const data = await response
    .json()
    .catch(() => ({
      message:
        response.status === 403
          ? "Refresh the page and try again."
          : "Request failed. Please try again.",
    }));
  if (!response.ok) throw new Error(data.message || "Request failed.");
  return data as T;
}
const fields = [
  "id",
  "kind",
  "title",
  "category",
  "excerpt",
  "body",
  "youtube",
  "creator",
  "thumbnail",
  "status",
  "date",
  "minutes",
] as const;
function normalize(post: Record<string, unknown>): Post {
  return Object.fromEntries(
    fields.map((k) => [k, String(post[k] ?? "")]),
  ) as Post;
}
export async function loadPosts(): Promise<Post[]> {
  const result = await listPosts({
    filter: { status: { eq: "published" } },
    fields: [...fields],
    headers: buildCSRFHeaders(),
  });
  if (!result.success)
    throw new Error(result.errors.map((e) => e.message).join(" "));
  return result.data.map(normalize);
}
export async function loadPost(id: string): Promise<Post> {
  const result = await getPost({
    getBy: { id },
    fields: [...fields],
    headers: buildCSRFHeaders(),
  });
  if (!result.success || !result.data) throw new Error("Post not found.");
  return normalize(result.data);
}
export function date(value: string) {
  return value.includes("T")
    ? new Date(value).toLocaleDateString(undefined, {
        year: "numeric",
        month: "short",
        day: "numeric",
      })
    : value;
}
export function image(post: Post) {
  return (
    post.thumbnail ||
    (post.kind === "video"
      ? `https://i.ytimg.com/vi/${post.youtube}/hqdefault.jpg`
      : "")
  );
}
