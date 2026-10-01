// 開発用の環境にだけ置く秘密の値。無くても動くので、secrets.required には書かず（書くと、無いときにデプロイが失敗する）、型だけここで足す
interface Env {
  E2E_SIGN_IN_SECRET?: string | undefined;
}
