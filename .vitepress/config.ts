// VitePress documentation configuration file.
//
// This configuration uses the default VitePress theme, whose details can be
// found at https://vitepress.dev/reference/default-theme-config. For more
// information on VitePress configuration, visit
// https://vitepress.dev/reference/site-config.

import { defineConfig } from "vitepress";

export default defineConfig({
  base: "/shell-scripts",
  description: "Bounciness and tinyness in a loving package.",
  outDir: "site",
  srcDir: "docs",
  themeConfig: {
    nav: [
      { text: "Home", link: "/" },
      { text: "Install", link: "/install" },
    ],
    socialLinks: [
      { icon: "github", link: "https://github.com/scruffaluff/shell-scripts" },
    ],
  },
  title: "Shell Scripts",
});
