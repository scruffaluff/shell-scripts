module.exports = {
  base: "/shell-scripts/",
  plugins: [
    ["vuepress-plugin-code-copy", { color: "#FFFFFF", staticIcon: true }],
  ],
  themeConfig: {
    docsDir: "docs",
    editLinks: true,
    lastUpdated: "Last Updated",
    nav: [
      { text: "Home", link: "/" },
      { text: "Install", link: "/install/" },
    ],
    repo: "https://github.com/wolfgangwazzlestrauss/shell-scripts",
    smoothScroll: true,
  },
};
