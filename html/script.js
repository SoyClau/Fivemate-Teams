// ================================================
// Fivemate Teams - HUD JavaScript
// ================================================

let isHudVisible = false;
let currentMembers = [];
let isProcessingAction = false;  // Bandera para prevenir race conditions
let isDomReady = false;

// Esperar a que el DOM esté completamente cargado
document.addEventListener('DOMContentLoaded', function() {
    isDomReady = true;
    console.log('DOM fully loaded');
    
    // Asegurarse de que el HUD esté oculto al iniciar
    try {
        const hud = document.getElementById('clan-hud');
        if (hud) {
            hud.classList.add('hidden');
        }
    } catch (e) {
        console.error('Error al inicializar el HUD:', e);
    }
    
    // Agregar efectos de hover mejorados
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

// Escuchar mensajes de FiveM
window.addEventListener('message', function(event) {
    const data = event.data;
    
    // Si el DOM no está listo, esperar y reintentar
    if (!isDomReady) {
        setTimeout(() => {
            window.dispatchEvent(new MessageEvent('message', { data }));
        }, 100);
        return;
    }
    
    // Ping para verificar que la NUI está lista
    if (data.action === 'ping') {
        return;
    }
    
    // Prevenir race conditions esperando a que termine la acción anterior
    if (isProcessingAction) {
        setTimeout(() => {
            window.dispatchEvent(new MessageEvent('message', { data }));
        }, 50);
        return;
    }
    
    isProcessingAction = true;
    
    try {
        switch(data.action) {
            case 'showHUD':
                showHUD();
                break;
            case 'hideHUD':
                hideHUD();
                break;
            case 'updateHUD':
                if (data.members) {
                    updateMembers(data.members);
                } else {
                    console.error('Datos de miembros inválidos');
                }
                break;
            default:
                console.log('Acción desconocida:', data.action);
        }
    } catch (error) {
        console.error('Error procesando mensaje:', error);
    } finally {
        // Siempre liberar el bloqueo de procesamiento
        setTimeout(() => {
            isProcessingAction = false;
        }, 10);
    }
});

// Mostrar HUD
function showHUD() {
    try {
        const hud = document.getElementById('clan-hud');
        if (!hud) {
            console.error('No se pudo encontrar el elemento clan-hud');
            return;
        }
        
        hud.classList.remove('hidden');
        isHudVisible = true;
        console.log('HUD mostrado correctamente');
    } catch (error) {
        console.error('Error al mostrar HUD:', error);
    }
}

// Ocultar HUD
function hideHUD() {
    try {
        const hud = document.getElementById('clan-hud');
        if (!hud) {
            console.error('No se pudo encontrar el elemento clan-hud');
            return;
        }
        
        hud.classList.add('hidden');
        isHudVisible = false;
        
        // Limpiar datos para prevenir memory leaks
        currentMembers = [];
        console.log('HUD ocultado correctamente');
    } catch (error) {
        console.error('Error al ocultar HUD:', error);
    }
}

// Actualizar lista de miembros
function updateMembers(members) {
    try {
        if (!isHudVisible) return;
        
        // Validación defensiva
        if (!members) {
            console.error('members es null o undefined');
            return;
        }
        
        // Comprobar si los miembros han cambiado realmente para evitar actualizaciones innecesarias
        const membersJSON = JSON.stringify(members);
        const currentJSON = JSON.stringify(currentMembers);
        
        if (membersJSON === currentJSON) {
            return;
        }
        
        currentMembers = JSON.parse(membersJSON); // Crear una copia profunda
        
        const container = document.getElementById('clan-members');
        if (!container) {
            console.error('No se pudo encontrar el contenedor clan-members');
            return;
        }
        
        // Limpiar contenido anterior de forma segura
        while (container.firstChild) {
            container.removeChild(container.firstChild);
        }
        
        if (!members || members.length === 0) {
            const noMembers = document.createElement('div');
            noMembers.className = 'no-members';
            noMembers.textContent = 'No hay miembros del clan';
            container.appendChild(noMembers);
            return;
        }
        
        // Crear elementos de miembros
        members.forEach((member, index) => {
            try {
                if (!member) {
                    console.error('Miembro inválido en índice', index);
                    return;
                }
                
                const memberElement = createMemberElement(member, index);
                container.appendChild(memberElement);
            } catch (error) {
                console.error('Error creando elemento de miembro:', error, 'Datos:', member);
            }
        });
        
        console.log('Miembros actualizados correctamente');
    } catch (error) {
        console.error('Error en updateMembers:', error);
    }
}

// Crear elemento de miembro
function createMemberElement(member, index) {
    try {
        // Validaciones defensivas
        if (!member) {
            console.error('Miembro inválido');
            return document.createElement('div'); // Devolver un div vacío para evitar errores
        }
        
        if (!member.name) {
            member.name = 'Desconocido';
        }
        
        if (!member.role) {
            member.role = 'member';
        }
        
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
        
        try {
            if (member.isHeader) {
                content = `
                    <div class="member-name clan-title">${escapeHtml(member.name)}</div>
                `;
            } else if (member.isSelf) {
                // Si hideHealth es verdadero, no mostrar la barra de salud
                if (member.hideHealth) {
                    content = `
                        <div class="member-name">${escapeHtml(member.name)}</div>
                        <div class="member-info">
                            <span class="member-role">TÚ</span>
                        </div>
                    `;
                } else {
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
                }
            } else if (member.isInfo) {
                content = `
                    <div class="member-name info-text">${escapeHtml(member.name)}</div>
                `;
            } else {
                // Si hideHealth es verdadero, no mostrar la barra de salud
                if (member.hideHealth) {
                    content = `
                        <div class="member-name">${escapeHtml(member.name)}</div>
                        <div class="member-info">
                            <span class="member-role">${getRoleLabel(member.role)}</span>
                        </div>
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
            }
            
            div.innerHTML = content;
        } catch (error) {
            console.error('Error al generar contenido del miembro:', error);
            div.innerHTML = `<div class="member-name">Error al cargar miembro</div>`;
        }
        
        return div;
    } catch (error) {
        console.error('Error creando elemento de miembro:', error);
        const errorDiv = document.createElement('div');
        errorDiv.className = 'member-item error';
        errorDiv.innerHTML = '<div class="member-name">Error</div>';
        return errorDiv;
    }
}

// Obtener clase de salud según porcentaje
function getHealthClass(health) {
    try {
        // Asegurarse de que health es un número
        const healthNum = parseInt(health || 0);
        
        if (healthNum >= 75) return 'health-high';
        if (healthNum >= 50) return 'health-medium';
        if (healthNum >= 25) return 'health-low';
        return 'health-critical';
    } catch (error) {
        console.error('Error en getHealthClass:', error);
        return 'health-high'; // Valor predeterminado en caso de error
    }
}

// Obtener etiqueta de rol
function getRoleLabel(role) {
    try {
        if (!role) return 'Desconocido';
        
        const labels = {
            'leader': 'Líder',
            'sublider': 'Sub-Líder',
            'member': 'Miembro'
        };
        return labels[role] || 'Desconocido';
    } catch (error) {
        console.error('Error en getRoleLabel:', error);
        return 'Desconocido';
    }
}

// Escape HTML para prevenir XSS
function escapeHtml(text) {
    try {
        if (!text) return '';
        
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    } catch (error) {
        console.error('Error en escapeHtml:', error);
        return '';
    }
}

// Animación de entrada suave (versión segura)
function animateIn(element, delay = 0) {
    try {
        if (!element) return;
        
        setTimeout(() => {
            element.style.animation = 'slideIn 0.3s ease forwards';
        }, delay);
    } catch (error) {
        console.error('Error en animateIn:', error);
    }
}

// Funciones de utilidad para debugging
window.debugHUD = {
    show: showHUD,
    hide: hideHUD,
    update: updateMembers,
    test: function() {
        try {
            const testMembers = [
                {
                    name: 'TestPlayer1',
                    role: 'leader',
                    distance: 25,
                    health: 85,
                    color: '#FF6B6B',
                    hideHealth: true
                },
                {
                    name: 'TestPlayer2',
                    role: 'sublider',
                    distance: 45,
                    health: 60,
                    color: '#4ECDC4',
                    hideHealth: true
                },
                {
                    name: 'TestPlayer3',
                    role: 'member',
                    distance: 120,
                    health: 30,
                    color: '#45B7D1',
                    hideHealth: true
                }
            ];
            showHUD();
            updateMembers(testMembers);
            console.log('Test HUD activado');
        } catch (error) {
            console.error('Error en test:', error);
        }
    }
};