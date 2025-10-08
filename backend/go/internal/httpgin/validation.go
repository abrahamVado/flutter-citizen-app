package httpgin

import (
	"errors"
	"fmt"
	"net/http"
	"reflect"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

// 1.- requestValidator aplica las reglas declarativas sobre los DTO de entrada.
var requestValidator = newRequestValidator()

// 2.- newRequestValidator configura el validador compartido con reglas personalizadas.
func newRequestValidator() *validator.Validate {
	v := validator.New()
	v.RegisterTagNameFunc(func(fld reflect.StructField) string {
		tag := fld.Tag.Get("json")
		if tag == "" || tag == "-" {
			return fld.Name
		}
		parts := strings.Split(tag, ",")
		if parts[0] == "" {
			return fld.Name
		}
		return parts[0]
	})
	_ = v.RegisterValidation("phone_digits", validatePhoneDigits)
	return v
}

// 3.- validatePhoneDigits garantiza teléfonos de 10 a 15 dígitos con prefijo opcional.
func validatePhoneDigits(fl validator.FieldLevel) bool {
	phone := fl.Field().String()
	re := regexp.MustCompile(`^\+?[0-9]{10,15}$`)
	return re.MatchString(phone)
}

// 4.- decodeAndValidate centraliza el binding JSON y el mapeo de errores 400.
func decodeAndValidate(c *gin.Context, payload any) bool {
	if err := c.ShouldBindJSON(payload); err != nil {
		writeError(c, http.StatusBadRequest, "invalid payload")
		return false
	}
	if err := requestValidator.Struct(payload); err != nil {
		var ve validator.ValidationErrors
		if errors.As(err, &ve) {
			writeError(c, http.StatusBadRequest, formatValidationMessage(ve))
			return false
		}
		writeError(c, http.StatusBadRequest, "invalid payload")
		return false
	}
	return true
}

// 5.- formatValidationMessage traduce la primera violación en un mensaje legible.
func formatValidationMessage(errs validator.ValidationErrors) string {
	if len(errs) == 0 {
		return "invalid payload"
	}
	err := errs[0]
	field := err.Field()
	switch err.Tag() {
	case "required":
		return fmt.Sprintf("invalid payload: %s is required", field)
	case "email":
		return fmt.Sprintf("invalid payload: %s must be a valid email", field)
	case "min":
		return fmt.Sprintf("invalid payload: %s must be at least %s characters", field, err.Param())
	case "max":
		return fmt.Sprintf("invalid payload: %s must be at most %s characters", field, err.Param())
	case "gte":
		return fmt.Sprintf("invalid payload: %s must be greater than or equal to %s", field, err.Param())
	case "lte":
		return fmt.Sprintf("invalid payload: %s must be less than or equal to %s", field, err.Param())
	case "uri":
		return fmt.Sprintf("invalid payload: %s must contain valid URLs", field)
	case "oneof":
		return fmt.Sprintf("invalid payload: %s must be one of [%s]", field, strings.ReplaceAll(err.Param(), " ", ", "))
	case "phone_digits":
		return fmt.Sprintf("invalid payload: %s must contain 10 to 15 digits", field)
	default:
		return fmt.Sprintf("invalid payload: %s is invalid", field)
	}
}
