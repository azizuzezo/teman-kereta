import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Admin Teman Kereta",
    short_name: "TK Admin",
    description: "Panel admin untuk mengelola data transit Teman Kereta.",
    start_url: "/dashboard",
    display: "standalone",
    background_color: "#f3f5f9",
    theme_color: "#17376b",
    icons: [
      { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
