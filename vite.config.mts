import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { cpSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// The browser VAD (Silero via ONNX Runtime) loads its model, worklet and wasm from /vad/ at runtime,
// outside the Vite bundle, so copy them into public/ whenever Vite starts or builds.
const root = dirname(fileURLToPath(import.meta.url));
const vadDist = join(root, "node_modules/@ricky0123/vad-web/dist");
const ortDist = join(root, "node_modules/onnxruntime-web/dist");
const vadPublic = join(root, "public/vad");
mkdirSync(vadPublic, { recursive: true });
for (const file of [
  "silero_vad_v5.onnx",
  "silero_vad_legacy.onnx",
  "vad.worklet.bundle.min.js",
]) {
  cpSync(join(vadDist, file), join(vadPublic, file));
}
for (const file of [
  "ort-wasm.wasm",
  "ort-wasm-simd.wasm",
  "ort-wasm-threaded.wasm",
  "ort-wasm-simd-threaded.wasm",
]) {
  cpSync(join(ortDist, file), join(vadPublic, file));
}

export default defineConfig({
  plugins: [RubyPlugin(), react(), tailwindcss()],

  esbuild: {
    include: /\.js$/,
    exclude: [],
    loader: "jsx",
  },

  optimizeDeps: {
    esbuildOptions: {
      loader: {
        ".js": "jsx",
      },
    },
  },

  build: {
    sourcemap: true,
  },
});
