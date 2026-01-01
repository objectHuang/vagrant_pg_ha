#!/bin/bash
# Patroni Cluster Management Script
# Usage: sudo ./failover.sh <command>

set -e

PATRONI_CONFIG="/etc/patroni/patroni.yml"
ACTION=${1:-"status"}

show_help() {
    echo "PostgreSQL HA Cluster Management Script (Patroni)"
    echo ""
    echo "Usage: sudo ./failover.sh <command>"
    echo ""
    echo "Commands:"
    echo "  status      - Show cluster status (default)"
    echo "  switchover  - Perform a planned switchover to another node"
    echo "  failover    - Force failover (use when primary is down)"
    echo "  reinit      - Reinitialize a failed node"
    echo "  pause       - Pause automatic failover"
    echo "  resume      - Resume automatic failover"
    echo "  history     - Show failover history"
    echo ""
    echo "Examples:"
    echo "  ./failover.sh status"
    echo "  ./failover.sh switchover"
    echo "  ./failover.sh failover"
    echo ""
}

check_patronictl() {
    if ! command -v patronictl &> /dev/null; then
        echo "ERROR: patronictl not found. Is Patroni installed?"
        exit 1
    fi
}

case $ACTION in
    status)
        check_patronictl
        echo "=== PostgreSQL HA Cluster Status ==="
        echo ""
        patronictl -c ${PATRONI_CONFIG} list
        echo ""
        ;;
    
    switchover)
        check_patronictl
        echo "=== Planned Switchover ==="
        echo "This will gracefully switch the primary role to another node."
        echo ""
        patronictl -c ${PATRONI_CONFIG} list
        echo ""
        patronictl -c ${PATRONI_CONFIG} switchover
        ;;
    
    failover)
        check_patronictl
        echo "=== Forced Failover ==="
        echo "WARNING: Use this only when the primary is completely unavailable!"
        echo ""
        patronictl -c ${PATRONI_CONFIG} list
        echo ""
        patronictl -c ${PATRONI_CONFIG} failover
        ;;
    
    reinit)
        check_patronictl
        echo "=== Reinitialize Node ==="
        echo "This will reinitialize a node from the current primary."
        echo ""
        patronictl -c ${PATRONI_CONFIG} list
        echo ""
        read -p "Enter node name to reinitialize: " NODE_NAME
        patronictl -c ${PATRONI_CONFIG} reinit pg-cluster ${NODE_NAME}
        ;;
    
    pause)
        check_patronictl
        echo "=== Pausing Automatic Failover ==="
        patronictl -c ${PATRONI_CONFIG} pause
        echo "Automatic failover is now PAUSED."
        echo "Run './failover.sh resume' to re-enable."
        ;;
    
    resume)
        check_patronictl
        echo "=== Resuming Automatic Failover ==="
        patronictl -c ${PATRONI_CONFIG} resume
        echo "Automatic failover is now ACTIVE."
        ;;
    
    history)
        check_patronictl
        echo "=== Failover History ==="
        patronictl -c ${PATRONI_CONFIG} history
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        echo "Unknown command: $ACTION"
        echo ""
        show_help
        exit 1
        ;;
esac
