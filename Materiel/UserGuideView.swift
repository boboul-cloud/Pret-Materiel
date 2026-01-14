//
//  UserGuideView.swift
//  Materiel
//
//  Mode d'emploi complet de l'application
//

import SwiftUI

// MARK: - Catégories du guide
enum GuideCategory: String, CaseIterable, Identifiable {
    case start = "Démarrage"
    case management = "Gestion"
    case rental = "Location & Commerce"
    case organization = "Organisation"
    case security = "Sécurité & Sauvegarde"
    case tips = "Conseils"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .start: return "play.circle.fill"
        case .management: return "folder.fill"
        case .rental: return "eurosign.circle.fill"
        case .organization: return "rectangle.3.group.fill"
        case .security: return "shield.fill"
        case .tips: return "lightbulb.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .start: return .blue
        case .management: return .green
        case .rental: return .orange
        case .organization: return .purple
        case .security: return .red
        case .tips: return .yellow
        }
    }
    
    var localizedName: LocalizedStringKey {
        switch self {
        case .start: return LocalizedStringKey("guide_cat_start")
        case .management: return LocalizedStringKey("guide_cat_management")
        case .rental: return LocalizedStringKey("guide_cat_rental")
        case .organization: return LocalizedStringKey("guide_cat_organization")
        case .security: return LocalizedStringKey("guide_cat_security")
        case .tips: return LocalizedStringKey("guide_cat_tips")
        }
    }
}

struct UserGuideView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: GuideCategory = .start
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Sélecteur de catégorie
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(GuideCategory.allCases) { category in
                                    CategoryButton(
                                        category: category,
                                        isSelected: selectedCategory == category
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCategory = category
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Contenu selon la catégorie
                        VStack(alignment: .leading, spacing: 20) {
                            switch selectedCategory {
                            case .start:
                                startContent
                            case .management:
                                managementContent
                            case .rental:
                                rentalContent
                            case .organization:
                                organizationContent
                            case .security:
                                securityContent
                            case .tips:
                                tipsContent
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle(LocalizedStringKey("Mode d'emploi"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Démarrage
    private var startContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GuideSection(
                icon: "info.circle.fill",
                iconColor: .blue,
                title: LocalizedStringKey("guide_intro_title"),
                content: LocalizedStringKey("guide_intro_content")
            )
            
            GuideSection(
                icon: "house.fill",
                iconColor: .blue,
                title: LocalizedStringKey("guide_home_title"),
                content: LocalizedStringKey("guide_home_content")
            )
            
            GuideSection(
                icon: "camera.fill",
                iconColor: .purple,
                title: LocalizedStringKey("guide_quick_create_title"),
                content: LocalizedStringKey("guide_quick_create_content")
            )
            
            GuideSection(
                icon: "hand.tap.fill",
                iconColor: .green,
                title: LocalizedStringKey("guide_navigation_title"),
                content: LocalizedStringKey("guide_navigation_content")
            )
            
            GuideSection(
                icon: "globe",
                iconColor: .teal,
                title: LocalizedStringKey("guide_language_title"),
                content: LocalizedStringKey("guide_language_content")
            )
        }
    }
    
    // MARK: - Gestion
    private var managementContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GuideSection(
                icon: "cube.box.fill",
                iconColor: .orange,
                title: LocalizedStringKey("guide_equipment_title"),
                content: LocalizedStringKey("guide_equipment_content")
            )
            
            GuideSection(
                icon: "photo.fill",
                iconColor: .blue,
                title: LocalizedStringKey("guide_photos_title"),
                content: LocalizedStringKey("guide_photos_content")
            )
            
            GuideSection(
                icon: "arrow.up.forward.circle.fill",
                iconColor: .green,
                title: LocalizedStringKey("guide_loans_title"),
                content: LocalizedStringKey("guide_loans_content")
            )
            
            GuideSection(
                icon: "arrow.down.backward.circle.fill",
                iconColor: .purple,
                title: LocalizedStringKey("guide_borrows_title"),
                content: LocalizedStringKey("guide_borrows_content")
            )
            
            GuideSection(
                icon: "arrow.triangle.swap",
                iconColor: .indigo,
                title: LocalizedStringKey("guide_lend_borrow_title"),
                content: LocalizedStringKey("guide_lend_borrow_content")
            )
            
            GuideSection(
                icon: "wrench.and.screwdriver.fill",
                iconColor: .red,
                title: LocalizedStringKey("guide_repairs_title"),
                content: LocalizedStringKey("guide_repairs_content")
            )
            
            GuideSection(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: LocalizedStringKey("guide_return_title"),
                content: LocalizedStringKey("guide_return_content")
            )
        }
    }
    
    // MARK: - Location & Commerce
    private var rentalContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GuideSection(
                icon: "eurosign.circle.fill",
                iconColor: .green,
                title: LocalizedStringKey("guide_rentals_title"),
                content: LocalizedStringKey("guide_rentals_content")
            )
            
            GuideSection(
                icon: "banknote.fill",
                iconColor: .yellow,
                title: LocalizedStringKey("guide_caution_title"),
                content: LocalizedStringKey("guide_caution_content")
            )
            
            GuideSection(
                icon: "arrow.triangle.swap",
                iconColor: .teal,
                title: LocalizedStringKey("guide_sublet_title"),
                content: LocalizedStringKey("guide_sublet_content")
            )
            
            GuideSection(
                icon: "cart.fill",
                iconColor: .purple,
                title: LocalizedStringKey("guide_myrentals_title"),
                content: LocalizedStringKey("guide_myrentals_content")
            )
            
            GuideSection(
                icon: "eurosign.arrow.circlepath",
                iconColor: .orange,
                title: LocalizedStringKey("guide_myrentals_caution_title"),
                content: LocalizedStringKey("guide_myrentals_caution_content")
            )
            
            GuideSection(
                icon: "cart.fill",
                iconColor: .blue,
                title: LocalizedStringKey("guide_commerce_title"),
                content: LocalizedStringKey("guide_commerce_content")
            )
            
            GuideSection(
                icon: "tag.fill",
                iconColor: .orange,
                title: LocalizedStringKey("guide_articles_title"),
                content: LocalizedStringKey("guide_articles_content")
            )
            
            GuideSection(
                icon: "arrow.left.arrow.right",
                iconColor: .purple,
                title: LocalizedStringKey("guide_transactions_title"),
                content: LocalizedStringKey("guide_transactions_content")
            )
            
            GuideSection(
                icon: "chart.bar.fill",
                iconColor: .purple,
                title: LocalizedStringKey("guide_accounting_title"),
                content: LocalizedStringKey("guide_accounting_content")
            )
            
            GuideSection(
                icon: "chart.pie.fill",
                iconColor: .orange,
                title: LocalizedStringKey("guide_commerce_accounting_title"),
                content: LocalizedStringKey("guide_commerce_accounting_content")
            )
        }
    }
    
    // MARK: - Organisation
    private var organizationContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GuideSection(
                icon: "person.2.fill",
                iconColor: .pink,
                title: LocalizedStringKey("guide_people_title"),
                content: LocalizedStringKey("guide_people_content")
            )
            
            GuideSection(
                icon: "person.badge.clock.fill",
                iconColor: .green,
                title: LocalizedStringKey("guide_people_types_title"),
                content: LocalizedStringKey("guide_people_types_content")
            )
            
            GuideSection(
                icon: "person.2.badge.gearshape.fill",
                iconColor: .orange,
                title: LocalizedStringKey("guide_duplicates_title"),
                content: LocalizedStringKey("guide_duplicates_content")
            )
            
            GuideSection(
                icon: "building.2.fill",
                iconColor: .orange,
                title: LocalizedStringKey("guide_worksites_title"),
                content: LocalizedStringKey("guide_worksites_content")
            )
            
            GuideSection(
                icon: "location.fill",
                iconColor: .teal,
                title: LocalizedStringKey("guide_locations_title"),
                content: LocalizedStringKey("guide_locations_content")
            )
            
            GuideSection(
                icon: "folder.fill",
                iconColor: .blue,
                title: LocalizedStringKey("guide_categories_title"),
                content: LocalizedStringKey("guide_categories_content")
            )
            
            GuideSection(
                icon: "magnifyingglass",
                iconColor: .indigo,
                title: LocalizedStringKey("guide_search_title"),
                content: LocalizedStringKey("guide_search_content")
            )
            
            GuideSection(
                icon: "flag.fill",
                iconColor: .red,
                title: LocalizedStringKey("guide_status_title"),
                content: LocalizedStringKey("guide_status_content")
            )
        }
    }
    
    // MARK: - Sécurité & Sauvegarde
    private var securityContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GuideSection(
                icon: "lock.shield.fill",
                iconColor: .orange,
                title: LocalizedStringKey("guide_safe_title"),
                content: LocalizedStringKey("guide_safe_content")
            )
            
            GuideSection(
                icon: "faceid",
                iconColor: .blue,
                title: LocalizedStringKey("guide_biometric_title"),
                content: LocalizedStringKey("guide_biometric_content")
            )
            
            GuideSection(
                icon: "key.fill",
                iconColor: .yellow,
                title: LocalizedStringKey("guide_password_title"),
                content: LocalizedStringKey("guide_password_content")
            )
            
            GuideSection(
                icon: "doc.text.fill",
                iconColor: .green,
                title: LocalizedStringKey("guide_invoices_title"),
                content: LocalizedStringKey("guide_invoices_content")
            )
            
            GuideSection(
                icon: "square.and.arrow.up.fill",
                iconColor: .cyan,
                title: LocalizedStringKey("guide_backup_title"),
                content: LocalizedStringKey("guide_backup_content")
            )
            
            GuideSection(
                icon: "doc.richtext.fill",
                iconColor: .red,
                title: LocalizedStringKey("guide_pdf_title"),
                content: LocalizedStringKey("guide_pdf_content")
            )
            
            GuideSection(
                icon: "doc.badge.arrow.up.fill",
                iconColor: .blue,
                title: LocalizedStringKey("guide_json_title"),
                content: LocalizedStringKey("guide_json_content")
            )
            
            GuideSection(
                icon: "photo.fill.on.rectangle.fill",
                iconColor: .purple,
                title: LocalizedStringKey("guide_image_quality_title"),
                content: LocalizedStringKey("guide_image_quality_content")
            )
        }
    }
    
    // MARK: - Conseils
    private var tipsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GuideSection(
                icon: "lightbulb.fill",
                iconColor: .yellow,
                title: LocalizedStringKey("guide_tips_title"),
                content: LocalizedStringKey("guide_tips_content")
            )
            
            GuideSection(
                icon: "star.fill",
                iconColor: .orange,
                title: LocalizedStringKey("guide_best_practices_title"),
                content: LocalizedStringKey("guide_best_practices_content")
            )
            
            GuideSection(
                icon: "envelope.fill",
                iconColor: .blue,
                title: LocalizedStringKey("guide_email_title"),
                content: LocalizedStringKey("guide_email_content")
            )
            
            GuideSection(
                icon: "bell.fill",
                iconColor: .red,
                title: LocalizedStringKey("guide_alerts_title"),
                content: LocalizedStringKey("guide_alerts_content")
            )
            
            GuideSection(
                icon: "infinity",
                iconColor: .gray,
                title: LocalizedStringKey("guide_capacity_title"),
                content: LocalizedStringKey("guide_capacity_content")
            )
            
            GuideSection(
                icon: "crown.fill",
                iconColor: .purple,
                title: LocalizedStringKey("guide_premium_title"),
                content: LocalizedStringKey("guide_premium_content")
            )
            
            GuideSection(
                icon: "questionmark.circle.fill",
                iconColor: .green,
                title: LocalizedStringKey("guide_faq_title"),
                content: LocalizedStringKey("guide_faq_content")
            )
        }
    }
}

// MARK: - Bouton de catégorie
struct CategoryButton: View {
    let category: GuideCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(category.localizedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : category.color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

struct GuideSection: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let content: LocalizedStringKey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    UserGuideView()
}
