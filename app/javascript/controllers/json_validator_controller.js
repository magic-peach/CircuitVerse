import { Controller } from "@hotwired/stimulus"

// Validates JSON textarea fields in real-time.
// Usage:
//   <form data-controller="json-validator">
//     <textarea data-json-validator-target="field" ...></textarea>
//   </form>
export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.fieldTargets.forEach(field => {
      this._ensureErrorEl(field)
      this._validate(field)
    })
  }

  validate(event) {
    this._validate(event.target)
  }

  // Block form submission if any field is invalid.
  submit(event) {
    const invalid = this.fieldTargets.some(f => f.classList.contains("is-invalid"))
    if (invalid) {
      event.preventDefault()
      event.stopPropagation()
      this.fieldTargets
        .filter(f => f.classList.contains("is-invalid"))
        .forEach(f => f.focus())
    }
  }

  _validate(field) {
    const raw = field.value.trim()
    if (raw === "") {
      field.classList.remove("is-invalid", "is-valid")
      this._errorEl(field).textContent = ""
      return
    }
    try {
      JSON.parse(raw)
      field.classList.remove("is-invalid")
      field.classList.add("is-valid")
      this._errorEl(field).textContent = ""
    } catch (e) {
      field.classList.remove("is-valid")
      field.classList.add("is-invalid")
      this._errorEl(field).textContent = `Invalid JSON: ${e.message}`
    }
  }

  _ensureErrorEl(field) {
    if (!this._errorEl(field)) {
      const el = document.createElement("div")
      el.className = "invalid-feedback"
      el.dataset.jsonValidatorError = "true"
      field.insertAdjacentElement("afterend", el)
    }
  }

  _errorEl(field) {
    return field.nextElementSibling?.dataset?.jsonValidatorError
      ? field.nextElementSibling
      : field.parentElement.querySelector("[data-json-validator-error]")
  }
}
