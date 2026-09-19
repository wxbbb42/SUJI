import { createHandler } from "./handler.mjs";

Deno.serve(createHandler({
  supabaseURL: Deno.env.get("SUPABASE_URL"),
  anonKey: Deno.env.get("SUPABASE_ANON_KEY"),
  deepseekKey: Deno.env.get("DEEPSEEK_API_KEY"),
}));
