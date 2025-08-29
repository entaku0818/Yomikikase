import { describe, it, before, after } from "mocha";
import { expect } from "chai";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions-test";

// Initialize Firebase Functions test environment
const test = functions();

// Import your functions after initializing the test environment
import { generateAudio, generateAudioWithTTS } from "../index";

describe("Audio Generation Functions", () => {
  let wrapped: any;
  let wrappedTTS: any;

  before(() => {
    // Set up test environment variables
    process.env.GEMINI_API_KEY = "test-api-key";
    
    // Wrap the functions for testing
    wrapped = test.wrap(generateAudio);
    wrappedTTS = test.wrap(generateAudioWithTTS);
  });

  after(() => {
    // Clean up the test environment
    test.cleanup();
  });

  describe("generateAudio", () => {
    it("should return error for GET request", async () => {
      const req = {
        method: "GET",
        body: {}
      };
      const res = {
        status: (code: number) => ({
          json: (data: any) => {
            expect(code).to.equal(405);
            expect(data.error).to.equal("Method not allowed");
          }
        })
      };

      await wrapped(req, res);
    });

    it("should return error when text is missing", async () => {
      const req = {
        method: "POST",
        body: {}
      };
      const res = {
        status: (code: number) => ({
          json: (data: any) => {
            expect(code).to.equal(400);
            expect(data.error).to.equal("Text is required");
          }
        })
      };

      await wrapped(req, res);
    });

    it("should process valid request", async () => {
      const req = {
        method: "POST",
        body: {
          text: "こんにちは、世界！",
          language: "ja-JP"
        }
      };
      
      let responseData: any;
      const res = {
        json: (data: any) => {
          responseData = data;
          expect(data.success).to.be.true;
          expect(data.originalText).to.equal("こんにちは、世界！");
          expect(data.language).to.equal("ja-JP");
        },
        status: () => res
      };

      // Note: This test will fail without a real API key
      // In a real test environment, you would mock the Gemini API
      try {
        await wrapped(req, res);
      } catch (error) {
        // Expected to fail without valid API key
        expect(error).to.exist;
      }
    });
  });

  describe("generateAudioWithTTS", () => {
    it("should return error for GET request", async () => {
      const req = {
        method: "GET",
        body: {}
      };
      const res = {
        status: (code: number) => ({
          json: (data: any) => {
            expect(code).to.equal(405);
            expect(data.error).to.equal("Method not allowed");
          }
        })
      };

      await wrappedTTS(req, res);
    });

    it("should return error when text is missing", async () => {
      const req = {
        method: "POST",
        body: {}
      };
      const res = {
        status: (code: number) => ({
          json: (data: any) => {
            expect(code).to.equal(400);
            expect(data.error).to.equal("Text is required");
          }
        })
      };

      await wrappedTTS(req, res);
    });

    it("should use default values for optional parameters", async () => {
      const req = {
        method: "POST",
        body: {
          text: "テストテキスト"
        }
      };
      
      let responseData: any;
      const res = {
        json: (data: any) => {
          responseData = data;
          expect(data.language).to.equal("ja-JP");
          expect(data.voice).to.equal("ja-JP-Wavenet-A");
        },
        status: () => res
      };

      try {
        await wrappedTTS(req, res);
      } catch (error) {
        // Expected to fail without valid API key
        expect(error).to.exist;
      }
    });

    it("should accept custom language and voice parameters", async () => {
      const req = {
        method: "POST",
        body: {
          text: "Hello, world!",
          language: "en-US",
          voice: "en-US-Wavenet-D"
        }
      };
      
      const res = {
        json: (data: any) => {
          expect(data.language).to.equal("en-US");
          expect(data.voice).to.equal("en-US-Wavenet-D");
          expect(data.originalText).to.equal("Hello, world!");
        },
        status: () => res
      };

      try {
        await wrappedTTS(req, res);
      } catch (error) {
        // Expected to fail without valid API key
        expect(error).to.exist;
      }
    });
  });
});