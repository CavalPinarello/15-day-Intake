import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";

const http = httpRouter();

// Seed test users endpoint - GET request for easy browser access
// Usage: https://enchanted-terrier-633.convex.site/seed-users
http.route({
  path: "/seed-users",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    try {
      const result = await ctx.runMutation(api.users.seedTestUsers, {
        hashType: "sha256",
      });

      return new Response(
        JSON.stringify({
          success: true,
          message: "Test users seeded successfully!",
          details: result,
          instructions: "You can now log in with user1-user10, password: 1",
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    } catch (error) {
      return new Response(
        JSON.stringify({
          success: false,
          error: String(error),
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }
  }),
});

export default http;
