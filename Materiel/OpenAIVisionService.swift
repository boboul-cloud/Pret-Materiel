//
//  OpenAIVisionService.swift
//  Materiel
//
//  Service de reconnaissance d'image via OpenAI Vision (GPT-4o)
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Résultat de reconnaissance IA
struct AIRecognitionResult {
    let nom: String              // Nom suggéré pour le matériel
    let categorie: String        // Catégorie suggérée
    let marque: String?          // Marque détectée
    let modele: String?          // Modèle détecté
    let description: String      // Description générée
    let confidence: String       // "haute", "moyenne", "faible"
}

// MARK: - Service OpenAI Vision
class OpenAIVisionService: ObservableObject {
    static let shared = OpenAIVisionService()
    
    @Published var isProcessing = false
    @Published var lastResult: AIRecognitionResult?
    @Published var error: String?
    
    // Clé API stockée dans UserDefaults
    private let apiKeyKey = "OpenAI_API_Key"
    
    var apiKey: String? {
        get { UserDefaults.standard.string(forKey: apiKeyKey) }
        set { 
            UserDefaults.standard.set(newValue, forKey: apiKeyKey)
            objectWillChange.send()
        }
    }
    
    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty && key.hasPrefix("sk-")
    }
    
    private init() {}
    
    // MARK: - Analyse d'image avec OpenAI Vision
    func analyzeImage(_ image: UIImage, completion: @escaping (Result<AIRecognitionResult, Error>) -> Void) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.failure(AIError.noAPIKey))
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(AIError.invalidImage))
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.error = nil
        }
        
        // Construire la requête OpenAI
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let prompt = """
        Analyse cette image d'un objet/matériel et réponds UNIQUEMENT en JSON valide avec ce format exact:
        {
            "nom": "Nom court et descriptif de l'objet",
            "categorie": "Une seule catégorie parmi: Électronique, Outillage, Audiovisuel, Informatique, Mobilier, Jardinage, Sport, Cuisine, Bricolage, Véhicule, Médical, Bureautique, Instruments de musique, Autre",
            "marque": "Marque si visible, sinon null",
            "modele": "Numéro de modèle si visible, sinon null",
            "description": "Brève description de l'objet (1-2 phrases)",
            "confidence": "haute si l'objet est clairement identifiable, moyenne si partiellement visible, faible si difficile à identifier"
        }
        
        Réponds UNIQUEMENT avec le JSON, sans texte avant ou après.
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "low"  // low = moins cher, suffisant pour identification
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(.failure(AIError.requestFailed))
            }
            return
        }
        
        // Envoyer la requête
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    self?.error = "Pas de réponse du serveur"
                    completion(.failure(AIError.noResponse))
                    return
                }
                
                // Parser la réponse OpenAI
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Vérifier s'il y a une erreur
                        if let errorInfo = json["error"] as? [String: Any],
                           let message = errorInfo["message"] as? String {
                            self?.error = message
                            completion(.failure(AIError.apiError(message)))
                            return
                        }
                        
                        // Extraire le contenu
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let message = firstChoice["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            
                            // Parser le JSON de la réponse
                            let result = self?.parseAIResponse(content)
                            if let result = result {
                                self?.lastResult = result
                                completion(.success(result))
                            } else {
                                self?.error = "Impossible d'analyser la réponse"
                                completion(.failure(AIError.parseError))
                            }
                        } else {
                            self?.error = "Format de réponse inattendu"
                            completion(.failure(AIError.parseError))
                        }
                    }
                } catch {
                    self?.error = "Erreur de parsing: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Parser la réponse JSON de l'IA
    private func parseAIResponse(_ content: String) -> AIRecognitionResult? {
        // Nettoyer le contenu (parfois l'IA ajoute des backticks)
        let cleanContent = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let nom = json["nom"] as? String ?? "Matériel non identifié"
        let categorie = json["categorie"] as? String ?? "Autre"
        let marque = json["marque"] as? String
        let modele = json["modele"] as? String
        let description = json["description"] as? String ?? ""
        let confidence = json["confidence"] as? String ?? "moyenne"
        
        return AIRecognitionResult(
            nom: nom,
            categorie: categorie,
            marque: marque,
            modele: modele,
            description: description,
            confidence: confidence
        )
    }
}

// MARK: - Erreurs
enum AIError: LocalizedError {
    case noAPIKey
    case invalidImage
    case requestFailed
    case noResponse
    case parseError
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Clé API OpenAI non configurée. Allez dans Réglages pour l'ajouter."
        case .invalidImage:
            return "Image invalide ou corrompue"
        case .requestFailed:
            return "Échec de la requête"
        case .noResponse:
            return "Pas de réponse du serveur"
        case .parseError:
            return "Impossible d'analyser la réponse de l'IA"
        case .apiError(let message):
            return message
        }
    }
}
