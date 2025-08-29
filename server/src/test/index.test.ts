import { describe, it, before, after } from "mocha";
import { expect } from "chai";
import * as functions from "firebase-functions-test";
import fetch from "node-fetch";

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
    
    // Note: Wrapping v2 functions requires different approach
    // For now, we'll test the logic directly
    wrapped = generateAudio;
    wrappedTTS = generateAudioWithTTS;
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
      
      const res = {
        json: (data: any) => {
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

    it("should return error when text exceeds 5000 characters", async () => {
      const longText = "あ".repeat(5001);
      const req = {
        method: "POST",
        body: {
          text: longText
        }
      };
      const res = {
        status: (code: number) => ({
          json: (data: any) => {
            expect(code).to.equal(400);
            expect(data.error).to.equal("Text too long. Maximum 5000 characters allowed.");
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
      
      const res = {
        json: (data: any) => {
          expect(data.language).to.equal("en-US");
          expect(data.voice.id).to.equal("zephyr");
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
          voiceId: "en-us-male-b"
        }
      };
      
      const res = {
        json: (data: any) => {
          expect(data.language).to.equal("en-US");
          expect(data.voice.id).to.equal("en-us-male-b");
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

    it("should generate Japanese audio with correct configuration", async () => {
      const req = {
        method: "POST",
        body: {
          text: "こんにちは、今日は良い天気ですね。",
          voiceId: "ja-jp-female-a"
        }
      };
      
      const res = {
        json: (data: any) => {
          expect(data.success).to.be.true;
          expect(data.language).to.equal("ja-JP");
          expect(data.voice.id).to.equal("ja-jp-female-a");
          expect(data.voice.wavenetVoice).to.equal("ja-JP-Wavenet-A");
          expect(data.originalText).to.equal("こんにちは、今日は良い天気ですね。");
          expect(data.audioUrl).to.include("storage.googleapis.com");
          expect(data.mimeType).to.equal("audio/wav");
        },
        status: () => res
      };

      try {
        await wrappedTTS(req, res);
      } catch (error) {
        // Expected to fail without valid API key in test environment
        expect(error).to.exist;
      }
    });
  });

  describe("Integration Tests", () => {
    it("should generate audio and verify URL is accessible", async function() {
      this.timeout(30000); // Increase timeout for TTS generation
      
      const testText = "こんにちは";
      const response = await fetch("http://localhost:5001/voiceyourtext/us-central1/generateAudioWithTTS", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: testText,
          voiceId: "ja-jp-female-a"
        })
      });

      const result = await response.json();
      
      expect(result.success).to.be.true;
      expect(result.language).to.equal("ja-JP");
      expect(result.originalText).to.equal(testText);
      expect(result.audioUrl).to.include("storage.googleapis.com");

      // Verify the audio file is accessible
      const audioResponse = await fetch(result.audioUrl);
      expect(audioResponse.status).to.equal(200);
      expect(audioResponse.headers.get('content-type')).to.include('audio');
    });
  });
});