
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Verify the user is authenticated
    const authorization = req.headers.get("Authorization");

    if (!authorization) {
      return new Response(
        JSON.stringify({ error: "Authorization required." }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { Authorization: authorization },
        },
        auth: {
          persistSession: false,
        },
      },
    );

    const { data: userData, error: authError } =
      await supabase.auth.getUser();

    if (authError || !userData.user) {
      return new Response(
        JSON.stringify({ error: "Invalid user session." }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2. Read and validate the request
    const body = await req.json();
    const message = body.message;
    const history = body.history ?? [];

    if (typeof message !== "string" || message.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Please provide a message." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (message.length > 4000) {
      return new Response(
        JSON.stringify({ error: "Message is too long." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!Array.isArray(history) || history.length > 20) {
      return new Response(
        JSON.stringify({ error: "Conversation history is invalid or too long." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    for (const item of history) {
      if (
        !item ||
        !["user", "assistant"].includes(item.role) ||
        typeof item.content !== "string" ||
        item.content.length > 4000
      ) {
        return new Response(
          JSON.stringify({ error: "Invalid conversation history item." }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
    }

    // 3. Get the protected OpenAI API key
    const openAIKey = Deno.env.get("OPENAI_API_KEY");

    if (!openAIKey) {
      throw new Error("OpenAI API key is not configured.");
    }

    // 4. Build the conversation for OpenAI
    const input = [
      {
        role: "developer",
        content:
          "You are Wellness AI, a supportive fitness and wellness assistant. " +
          "Be friendly, practical, encouraging, and concise. " +
          "Help users with fitness, healthy habits, workout planning, " +
          "general nutrition, motivation, and progress reflection. " +
          "Use the conversation history to understand follow-up questions " +
          "and maintain context. Do not diagnose medical conditions or " +
          "prescribe treatment. Encourage users to consult qualified " +
          "healthcare professionals for medical concerns. Never shame users " +
          "about their body, weight, food, or progress.",
      },
      ...history.map((item: { role: string; content: string }) => ({
        role: item.role,
        content: item.content,
      })),
      {
        role: "user",
        content: message,
      },
    ];

    // 5. Send the conversation to OpenAI
    const openAIResponse = await fetch(
      "https://api.openai.com/v1/responses",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${openAIKey}`,
        },
        body: JSON.stringify({
          model: "gpt-6-luna",
          input,
        }),
      },
    );

    const openAIData = await openAIResponse.json();

    if (!openAIResponse.ok) {
      console.error("OpenAI error:", openAIData);
      return new Response(
        JSON.stringify({ error: "AI request failed." }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 6. Extract the AI response
    const aiText = (openAIData.output ?? [])
      .flatMap((item: any) => item.content ?? [])
      .filter((item: any) => item.type === "output_text")
      .map((item: any) => item.text)
      .join("");

    if (!aiText) {
      throw new Error("OpenAI returned an empty response.");
    }

    // 7. Log successful requests without logging private messages
    console.log("Wellness AI request successful for user:", userData.user.id);

    // 8. Return the AI response
    return new Response(
      JSON.stringify({ reply: aiText }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Wellness Assistant error:", error);

    return new Response(
      JSON.stringify({ error: "Something went wrong processing your request." }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
