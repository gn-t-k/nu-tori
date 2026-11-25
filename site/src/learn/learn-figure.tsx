// 本文に置く図。site/public に置いた画像を、幅と高さを書いて描く（読み込みで本文がずれないように）
export const LearnFigure = ({
  src,
  alt,
  width,
  height,
}: {
  src: string;
  alt: string;
  width: number;
  height: number;
}) => <img class="learn-figure" src={src} alt={alt} width={width} height={height} loading="lazy" />;
