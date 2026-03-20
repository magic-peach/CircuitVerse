import { Controller } from 'stimulus';

export default class extends Controller {
    selectedEmails = [];

    connect() {
        this.setupMentorInput();
        $('#promote-member-modal').on('show.bs.modal', (e) => {
            const groupmember = $(e.relatedTarget).data('currentgroupmember');
            $(e.currentTarget).find('#groups-member-promote-button').parent().attr('action',
                `/group_members/${groupmember.toString()}`);
        });
        $('#demote-member-modal').on('show.bs.modal', (e) => {
            const groupmember = $(e.relatedTarget).data('currentgroupmember');
            $(e.currentTarget).find('#groups-member-demote-button').parent().attr('action',
                `/group_members/${groupmember.toString()}`);
        });
    }

    setupMentorInput() {
        const input = document.getElementById('mentor-email-input');
        if (!input) return;

        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' || e.key === ' ' || e.key === ',') {
                e.preventDefault();
                const email = input.value.trim().replace(/[,\s]+$/, '');
                if (email && this.isValidEmail(email)) {
                    this.addEmail(email);
                    input.value = '';
                }
            } else if (e.key === 'Backspace' && input.value === '' && this.selectedEmails.length > 0) {
                this.removeEmail(this.selectedEmails[this.selectedEmails.length - 1]);
            }
        });

        input.addEventListener('blur', () => {
            const email = input.value.trim();
            if (email && this.isValidEmail(email)) {
                this.addEmail(email);
                input.value = '';
            }
        });
    }

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    addEmail(email) {
        if (this.selectedEmails.includes(email)) return;
        this.selectedEmails.push(email);
        this.renderEmails();
        this.updateHiddenField();
        this.updateSubmitButton();
    }

    removeEmail(email) {
        this.selectedEmails = this.selectedEmails.filter(e => e !== email);
        this.renderEmails();
        this.updateHiddenField();
        this.updateSubmitButton();
    }

    renderEmails() {
        const container = document.getElementById('mentor-selected-emails');
        if (!container) return;
        
        container.innerHTML = this.selectedEmails.map(email => `
            <span style="display:inline-flex; align-items:center; gap:4px; background:#E1F5EE; color:#0F6E56; padding:4px 8px; border-radius:20px; font-size:0.82rem;">
                ${email}
                <button type="button" data-email="${email}" class="remove-mentor-email" style="background:none; border:none; cursor:pointer; color:#0F6E56; padding:0; line-height:1; font-size:14px;">&times;</button>
            </span>
        `).join('');
        
        container.querySelectorAll('.remove-mentor-email').forEach(btn => {
            btn.addEventListener('click', () => {
                this.removeEmail(btn.dataset.email);
            });
        });
    }

    updateHiddenField() {
        const form = document.querySelector('#add-mentor-panel form');
        const existingFields = form.querySelectorAll('input[name="group_member[emails][]"]');
        existingFields.forEach(f => f.remove());
        
        this.selectedEmails.forEach(email => {
            const hiddenField = document.createElement('input');
            hiddenField.type = 'hidden';
            hiddenField.name = 'group_member[emails][]';
            hiddenField.value = email;
            form.appendChild(hiddenField);
        });
    }

    updateSubmitButton() {
        const button = document.getElementById('add-mentor-button');
        const errorDiv = document.getElementById('mentor-email-error');
        if (button) {
            button.disabled = this.selectedEmails.length === 0;
            console.log('Button updated. Emails count:', this.selectedEmails.length, 'Button disabled:', button.disabled);
        }
        if (errorDiv) {
            errorDiv.style.display = 'none';
        }
    }
}
