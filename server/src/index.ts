import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { TextToSpeechClient } from "@google-cloud/text-to-speech";
import { getVoiceById, availableVoices } from "./voiceConfig";
import type { Request, Response } from "express";
import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";

// Helper function to validate environment variables
function validateEnvVar(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Required environment variable ${name} is not set`);
  }
  return value;
}

// Initialize Firebase Admin
admin.initializeApp();
const storage = admin.storage();

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
      const genAI = new GoogleGenerativeAI(validateEnvVar('GEMINI_API_KEY'));
      const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

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
        language, 
        voiceId = "en-us-female-a",
        style = "cheerfully"
      } = request.body;

      if (!text) {
        response.status(400).json({ error: "Text is required" });
        return;
      }

      if (text.length > 5000) {
        response.status(400).json({ error: "Text too long. Maximum 5000 characters allowed." });
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

      // Use voice language if not specified
      const actualLanguage = language || voiceConfig.language;

      logger.info("Generating audio with TTS:", { text, language: actualLanguage, voiceId, voiceConfig, style });

      // Use the original text directly for TTS
      const enhancedText = text;
      
      // Use Google Cloud Text-to-Speech
      const ttsClient = new TextToSpeechClient();
      
      const ttsRequest = {
        input: { text: enhancedText },
        voice: { 
          languageCode: actualLanguage,
          name: voiceConfig.wavenetVoice,
          ssmlGender: (voiceConfig.gender === 'female' ? 'FEMALE' : 'MALE') as 'FEMALE' | 'MALE'
        },
        audioConfig: { audioEncoding: 'LINEAR16' as const }
      };
      
      const [ttsResponse] = await ttsClient.synthesizeSpeech(ttsRequest);
      
      if (!ttsResponse.audioContent) {
        throw new Error("No audio content generated from TTS");
      }
      
      // Convert to base64 for consistency
      const audioData = Buffer.from(ttsResponse.audioContent as Uint8Array).toString('base64');
      
      if (!audioData) {
        throw new Error("No audio data generated");
      }

      // Convert base64 to buffer
      const audioBuffer = Buffer.from(audioData, 'base64');
      
      // Generate unique filename
      const timestamp = Date.now();
      const filename = `audio/${voiceConfig.id}_${timestamp}_${uuidv4()}.wav`;
      
      // Get a reference to the storage bucket
      const bucket = storage.bucket(validateEnvVar('STORAGE_BUCKET_NAME'));
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
        language: actualLanguage,
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