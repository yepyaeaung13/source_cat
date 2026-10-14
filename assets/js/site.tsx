import React, { createContext, useContext } from "react";
import type { AccountState } from "./api";
export type Site = {
  state: AccountState | null;
  saved: string[];
  refresh: () => Promise<void>;
  account: () => void;
  notify: (message: string) => void;
  save: (id: string) => Promise<void>;
};
export const SiteContext = createContext<Site | null>(null);
export function useSite() {
  const site = useContext(SiteContext);
  if (!site) throw new Error("Missing SourceCat context");
  return site;
}
