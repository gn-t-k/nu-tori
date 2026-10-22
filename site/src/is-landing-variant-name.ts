// LP の版の名前は、Cookie の値と書き出す先のパス（/_lp/<版>/）にそのまま入るので、英小文字と数字だけにする
export const isLandingVariantName = (name: string): boolean => /^[a-z0-9]+$/u.test(name);
