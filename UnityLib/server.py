#!/usr/bin/env python3
# ============================================================
# J++ XML NETWORK SERVER
# Python WebSocket server for J++ multiplayer
# BSD-2-Clause License
# ============================================================

import asyncio
import websockets
import xml.etree.ElementTree as ET
from datetime import datetime
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("JppServer")

class JppGameServer:
    def __init__(self):
        self.clients = {}  # websocket -> player_id
        self.players = {}  # player_id -> player_data
        self.rooms = {}    # room_id -> [player_ids]
        self.handlers = {
            'player-join': self.handle_join,
            'player-move': self.handle_move,
            'player-shoot': self.handle_shoot,
            'player-damage': self.handle_damage,
            'player-death': self.handle_death,
            'player-respawn': self.handle_respawn,
            'chat-message': self.handle_chat,
        }
    
    def create_xml_response(self, msg_type, attrs=None, payload=None):
        root = ET.Element('message')
        root.set('type', msg_type)
        root.set('timestamp', str(datetime.utcnow().timestamp()))
        
        if attrs:
            for k, v in attrs.items():
                root.set(k, str(v))
        
        if payload:
            ET.SubElement(root, 'payload').text = payload
        
        return ET.tostring(root, encoding='unicode')
    
    async def handle_join(self, websocket, msg):
        player_id = msg.get('playerId', 'unknown')
        self.clients[websocket] = player_id
        self.players[player_id] = {
            'websocket': websocket,
            'position': {'x': 0, 'y': 0, 'z': 0},
            'health': 100,
            'score': 0,
            'team': 0
        }
        
        logger.info(f"Player joined: {player_id}")
        
        # Broadcast to all players
        await self.broadcast('player-joined', {
            'playerId': player_id,
            'playerName': msg.get('deviceName', 'Player')
        }, exclude=websocket)
        
        # Send current player list
        for pid, pdata in self.players.items():
            if pid != player_id:
                await websocket.send(self.create_xml_response('player-joined', {
                    'playerId': pid,
                    'position': json.dumps(pdata['position'])
                }))
    
    async def handle_move(self, websocket, msg):
        player_id = self.clients.get(websocket)
        if not player_id:
            return
        
        # Update position
        pos = json.loads(msg.get('position', '{}'))
        self.players[player_id]['position'] = pos
        
        # Broadcast to others
        await self.broadcast('player-moved', {
            'playerId': player_id,
            'position': msg.get('position'),
            'rotation': msg.get('rotation')
        }, exclude=websocket)
    
    async def handle_shoot(self, websocket, msg):
        player_id = self.clients.get(websocket)
        if not player_id:
            return
        
        await self.broadcast('player-shot', {
            'playerId': player_id,
            'origin': msg.get('origin'),
            'direction': msg.get('direction'),
            'weaponId': msg.get('weaponId')
        }, exclude=websocket)
    
    async def handle_damage(self, websocket, msg):
        target_id = msg.get('target')
        damage = int(msg.get('damage', 0))
        
        if target_id in self.players:
            self.players[target_id]['health'] -= damage
            
            # Notify target
            target_ws = self.players[target_id]['websocket']
            await target_ws.send(self.create_xml_response('player-damaged', {
                'damage': str(damage),
                'attacker': msg.get('attacker'),
                'health': str(self.players[target_id]['health'])
            }))
            
            if self.players[target_id]['health'] <= 0:
                await self.handle_death(target_ws, {
                    'playerId': target_id,
                    'killer': msg.get('attacker')
                })
    
    async def handle_death(self, websocket, msg):
        player_id = msg.get('playerId')
        killer_id = msg.get('killer')
        
        if player_id in self.players:
            self.players[player_id]['health'] = 0
            
            # Update killer score
            if killer_id in self.players:
                self.players[killer_id]['score'] += 1
            
            await self.broadcast('player-died', {
                'playerId': player_id,
                'killer': killer_id
            })
    
    async def handle_respawn(self, websocket, msg):
        player_id = self.clients.get(websocket)
        if not player_id:
            return
        
        self.players[player_id]['health'] = 100
        
        await self.broadcast('player-respawned', {
            'playerId': player_id,
            'position': msg.get('position')
        })
    
    async def handle_chat(self, websocket, msg):
        player_id = self.clients.get(websocket)
        
        await self.broadcast('chat-message', {
            'playerId': player_id,
            'message': msg.get('message')
        })
    
    async def broadcast(self, msg_type, attrs, exclude=None):
        msg = self.create_xml_response(msg_type, attrs)
        tasks = []
        
        for ws in self.clients:
            if ws != exclude and ws.open:
                tasks.append(ws.send(msg))
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
    
    async def handle_client(self, websocket, path):
        try:
            async for message in websocket:
                try:
                    root = ET.fromstring(message)
                    msg_type = root.get('type', 'unknown')
                    attrs = {k: v for k, v in root.attrib.items() 
                            if k not in ['type', 'timestamp']}
                    
                    handler = self.handlers.get(msg_type)
                    if handler:
                        await handler(websocket, attrs)
                    else:
                        logger.warning(f"Unknown message type: {msg_type}")
                        
                except ET.ParseError as e:
                    logger.error(f"XML parse error: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            # Cleanup
            player_id = self.clients.pop(websocket, None)
            if player_id:
                self.players.pop(player_id, None)
                await self.broadcast('player-left', {'playerId': player_id})
                logger.info(f"Player left: {player_id}")

async def main():
    server = JppGameServer()
    async with websockets.serve(server.handle_client, "0.0.0.0", 8080):
        logger.info("J++ Game Server started on ws://0.0.0.0:8080")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())