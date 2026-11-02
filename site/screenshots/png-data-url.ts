// PNG のバイト列を、外を読まずに Chromium へ渡せる data: の URL にする
export const pngDataUrl = (png: Buffer): string =>
  `data:image/png;base64,${png.toString("base64")}`;
