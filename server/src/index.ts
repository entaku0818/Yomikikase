import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { getVoiceById, availableVoices, VoiceOption } from "./voiceConfig";
import { Request, Response } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";

// Initialize Firebase Admin
admin.initializeApp();
const storage = admin.storage();

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");

// Get available voices endpoint
export const getVoices = onRequest(
  { cors: true },
  async (request: Request, response: Response) => {
    try {
      if (request.method !== "GET") {
        response.status(405).json({ error: "Method not allowed" });
        return;
      }

      const { language } = request.query;

      let voices = availableVoices;
      
      if (language) {
        voices = availableVoices.filter(voice => voice.language === language);
      }

      response.json({
        success: true,
        voices: voices.map(voice => ({
          id: voice.id,
          name: voice.name,
          language: voice.language,
          gender: voice.gender,
          description: voice.description
        }))
      });

    } catch (error) {
      logger.error("Error getting voices:", error);
      response.status(500).json({
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error"
      });
    }
  }
);

export const generateAudio = onRequest(
  { cors: true },
  async (request: Request, response: Response) => {
    try {
      if (request.method !== "POST") {
        response.status(405).json({ error: "Method not allowed" });
        return;
      }

      const { text, language = "ja-JP" } = request.body;

      if (!text) {
        response.status(400).json({ error: "Text is required" });
        return;
      }

      logger.info("Generating audio for text:", { text, language });

      // Initialize Gemini model
      const model = genAI.getGenerativeModel({ model: "gemini-pro" });

      // Generate audio using Gemini API
      // Note: This is a placeholder as Gemini doesn't directly support audio generation
      // You may need to use a different service like Google Cloud Text-to-Speech
      const prompt = `Convert the following text to speech-ready format for ${language}: ${text}`;
      
      const result = await model.generateContent(prompt);
      const responseText = result.response.text();

      // For now, return the processed text
      // In a real implementation, you would use Text-to-Speech API
      response.json({
        success: true,
        processedText: responseText,
        originalText: text,
        language,
        message: "Audio generation completed (placeholder)"
      });

    } catch (error) {
      logger.error("Error generating audio:", error);
      response.status(500).json({
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error"
      });
    }
  }
);

export const generateAudioWithTTS = onRequest(
  { cors: true },
  async (request: Request, response: Response) => {
    try {
      if (request.method !== "POST") {
        response.status(405).json({ error: "Method not allowed" });
        return;
      }

      const { 
        text, 
        language = "en-US", 
        voiceId = "zephyr",
        style = "cheerfully"
      } = request.body;

      if (!text) {
        response.status(400).json({ error: "Text is required" });
        return;
      }

      // Get voice configuration
      const voiceConfig = getVoiceById(voiceId);
      if (!voiceConfig) {
        response.status(400).json({ 
          error: "Invalid voice ID",
          availableVoices: availableVoices.map(v => ({ id: v.id, name: v.name, language: v.language }))
        });
        return;
      }

      logger.info("Generating audio with TTS:", { text, language, voiceId, voiceConfig, style });

      // Use Gemini TTS model
      const model = genAI.getGenerativeModel({ 
        model: "gemini-2.0-flash-exp",
        generationConfig: {
          responseModalities: ["AUDIO"]
        }
      });

      // Create the TTS prompt with style
      const ttsPrompt = `Say ${style}: ${text}`;
      
      const result = await model.generateContent({
        contents: [{ parts: [{ text: ttsPrompt }] }],
        generationConfig: {
          responseModalities: ["AUDIO"],
          speechConfig: {
            voiceConfig: {
              prebuiltVoiceConfig: {
                voiceName: voiceConfig.wavenetVoice
              }
            }
          }
        }
      });

      // Extract audio data from response
      const audioData = result.response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
      
      if (!audioData) {
        throw new Error("No audio data generated");
      }

      // Convert base64 to buffer
      const audioBuffer = Buffer.from(audioData, 'base64');
      
      // Generate unique filename
      const timestamp = Date.now();
      const filename = `audio/${voiceConfig.id}_${timestamp}_${uuidv4()}.wav`;
      
      // Get a reference to the storage bucket
      const bucket = storage.bucket();
      const file = bucket.file(filename);
      
      // Save the audio file to Firebase Storage
      await file.save(audioBuffer, {
        metadata: {
          contentType: 'audio/wav',
          metadata: {
            originalText: text,
            voice: voiceConfig.id,
            language: language,
            style: style,
            timestamp: timestamp.toString()
          }
        }
      });
      
      // Make the file publicly accessible
      await file.makePublic();
      
      // Get the public URL
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;
      
      // Return the file URL
      response.json({
        success: true,
        originalText: text,
        language,
        voice: voiceConfig,
        style,
        audioUrl: publicUrl,
        filename: filename,
        mimeType: "audio/wav",
        message: "Audio generated and saved successfully"
      });

    } catch (error) {
      logger.error("Error generating audio with TTS:", error);
      response.status(500).json({
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error"
      });
    }
  }
);