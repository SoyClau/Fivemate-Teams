// ================================================
// Fivemate Teams - HUD JavaScript
// ================================================

let isHudVisible = false;
let currentMembers = [];

// Escuchar mensajes de FiveM
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'showHUD':
            showHUD();
            break;
        case 'hideHUD':
            hideHUD();
            break;
        case 'updateHUD':
            updateMembers(data.members);
            break;
    }
});

// Mostrar HUD
function showHUD() {
    const hud = document.getElementById('clan-hud');
    hud.classList.remove('hidden');
    isHudVisible = true;
}

// Ocultar HUD
function hideHUD() {
    const hud = document.getElementById('clan-hud');
    hud.classList.add('hidden');
    isHudVisible = false;
}

// Actualizar lista de miembros
function updateMembers(members) {
    if (!isHudVisible) return;
    
    currentMembers = members;
    const container = document.getElementById('clan-members');
    
    // Limpiar contenido anterior
    container.innerHTML = '';
    
    if (members.length === 0) {
        container.innerHTML = '<div class="no-members">No hay miembros del clan</div>';
        return;
    }
    
    // Crear elementos de miembros (sin ordenar por distancia)
    members.forEach((member, index) => {
        const memberElement = createMemberElement(member, index);
        container.appendChild(memberElement);
    });
}

// Crear elemento de miembro
function createMemberElement(member, index) {
    const div = document.createElement('div');
    let className = `member-item`;
    
    // Agregar clases especiales según el tipo
    if (member.isHeader) {
        className += ' member-header';
    } else if (member.isSelf) {
        className += ' member-self';
    } else if (member.isInfo) {
        className += ' member-info';
    } else {
        className += ` role-${member.role}`;
    }
    
    div.className = className;
    div.style.animationDelay = `${index * 0.1}s`;
    
    let content = '';
    
    if (member.isHeader) {
        content = `
            <div class="member-name clan-title">${escapeHtml(member.name)}</div>
        `;
    } else if (member.isSelf) {
        const healthClass = getHealthClass(member.health);
        content = `
            <div class="member-name">${escapeHtml(member.name)}</div>
            <div class="member-info">
                <span class="member-role">TÚ</span>
                <div class="member-stats">
                    <div class="member-health">
                        <div class="health-bar">
                            <div class="health-fill ${healthClass}" style="width: ${member.health}%"></div>
                        </div>
                        <span class="health-text">${member.health}%</span>
                    </div>
                </div>
            </div>
        `;
    } else if (member.isInfo) {
        content = `
            <div class="member-name info-text">${escapeHtml(member.name)}</div>
        `;
    } else {
        const healthClass = getHealthClass(member.health);
        content = `
            <div class="member-name">${escapeHtml(member.name)}</div>
            <div class="member-info">
                <span class="member-role">${getRoleLabel(member.role)}</span>
                <div class="member-stats">
                    <div class="member-health">
                        <div class="health-bar">
                            <div class="health-fill ${healthClass}" style="width: ${member.health}%"></div>
                        </div>
                        <span class="health-text">${member.health}%</span>
                    </div>
                </div>
            </div>
        `;
    }
    
    div.innerHTML = content;
    return div;
}

// Obtener clase de salud según porcentaje
function getHealthClass(health) {
    if (health >= 75) return 'health-high';
    if (health >= 50) return 'health-medium';
    if (health >= 25) return 'health-low';
    return 'health-critical';
}

// Obtener etiqueta de rol
function getRoleLabel(role) {
    const labels = {
        'leader': 'Líder',
        'sublider': 'Sub-Líder',
        'member': 'Miembro'
    };
    return labels[role] || 'Desconocido';
}

// Escape HTML para prevenir XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Animación de entrada suave
function animateIn(element, delay = 0) {
    setTimeout(() => {
        element.style.animation = 'slideIn 0.3s ease forwards';
    }, delay);
}

// Actualización de salud en tiempo real
function updateMemberHealth(citizenid, health) {
    const memberElements = document.querySelectorAll('.member-item');
    memberElements.forEach(element => {
        const memberData = currentMembers.find(m => m.citizenid === citizenid);
        if (memberData) {
            const healthBar = element.querySelector('.health-fill');
            const healthText = element.querySelector('.health-text');
            
            if (healthBar && healthText) {
                healthBar.style.width = `${health}%`;
                healthBar.className = `health-fill ${getHealthClass(health)}`;
                healthText.textContent = `${health}%`;
            }
        }
    });
}

// Efectos de hover mejorados
document.addEventListener('DOMContentLoaded', function() {
    // Agregar efectos de sonido si están disponibles
    document.addEventListener('mouseover', function(e) {
        if (e.target.classList.contains('member-item')) {
            e.target.style.transform = 'translateX(5px) scale(1.02)';
        }
    });
    
    document.addEventListener('mouseout', function(e) {
        if (e.target.classList.contains('member-item')) {
            e.target.style.transform = 'translateX(0) scale(1)';
        }
    });
});

// Funciones de utilidad para debugging
window.debugHUD = {
    show: showHUD,
    hide: hideHUD,
    update: updateMembers,
    test: function() {
        const testMembers = [
            {
                name: 'TestPlayer1',
                role: 'leader',
                distance: 25,
                health: 85,
                color: '#FF6B6B'
            },
            {
                name: 'TestPlayer2',
                role: 'sublider',
                distance: 45,
                health: 60,
                color: '#4ECDC4'
            },
            {
                name: 'TestPlayer3',
                role: 'member',
                distance: 120,
                health: 30,
                color: '#45B7D1'
            }
        ];
        showHUD();
        updateMembers(testMembers);
    }
};