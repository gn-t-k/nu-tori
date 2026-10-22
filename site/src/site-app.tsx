import { createSiteApp } from "./create-site-app";
import { sitePages } from "./site-pages";

// vite build の書き出しの元（vite.config.ts）
export default createSiteApp(sitePages);
