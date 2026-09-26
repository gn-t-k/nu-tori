import { app } from "../src/http/app";

const document = app.getOpenAPI31Document({
  openapi: "3.1.0",
  info: { title: "nu-tori", version: "1" },
});
console.log(JSON.stringify(document, null, 2));
