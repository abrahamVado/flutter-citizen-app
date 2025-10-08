package dto

import "strings"

// 1.- Package dto centraliza los contratos de entrada para el gateway HTTP.

// 2.- AuthCredentials representa el cuerpo esperado por login y registro.
type AuthCredentials struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
}

// 3.- RecoverRequest documenta el payload del endpoint de recuperación.
type RecoverRequest struct {
	Email string `json:"email" validate:"required,email"`
}

// 4.- ReportSubmissionRequest agrupa la información de un reporte ciudadano.
type ReportSubmissionRequest struct {
	IncidentTypeID string   `json:"incidentTypeId" validate:"required,min=1"`
	Description    string   `json:"description" validate:"required,max=2000"`
	ContactEmail   string   `json:"contactEmail" validate:"required,email"`
	ContactPhone   string   `json:"contactPhone" validate:"required,phone_digits"`
	Latitude       float64  `json:"latitude" validate:"required,gte=-90,lte=90"`
	Longitude      float64  `json:"longitude" validate:"required,gte=-180,lte=180"`
	Address        string   `json:"address" validate:"required,min=1,max=250"`
	EvidenceURLs   []string `json:"evidenceUrls" validate:"omitempty,dive,uri"`
}

// 5.- ToPayload transforma la solicitud en un mapa compatible con el servicio existente.
func (r ReportSubmissionRequest) ToPayload() map[string]any {
	payload := map[string]any{
		"incidentTypeId": r.IncidentTypeID,
		"description":    r.Description,
		"contactEmail":   r.ContactEmail,
		"contactPhone":   r.ContactPhone,
		"latitude":       r.Latitude,
		"longitude":      r.Longitude,
		"address":        r.Address,
	}
	if len(r.EvidenceURLs) > 0 {
		urls := make([]string, 0, len(r.EvidenceURLs))
		for _, u := range r.EvidenceURLs {
			trimmed := strings.TrimSpace(u)
			if trimmed != "" {
				urls = append(urls, trimmed)
			}
		}
		if len(urls) > 0 {
			payload["evidenceUrls"] = urls
		}
	}
	return payload
}

// 6.- ReportStatusUpdateRequest encapsula el cuerpo aceptado por PATCH /reports/{id}.
type ReportStatusUpdateRequest struct {
	Status string `json:"status" validate:"required,oneof=en_revision en_proceso resuelto critico"`
}
