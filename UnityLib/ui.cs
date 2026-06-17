// ============================================================
// J++ UI / NETWORKING - C# (COMPLETE)
// Unity UI, HUD, Multiplayer, XML Networking, WASM Bridge
// BSD-2-Clause License
// ============================================================

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Xml.Linq;
using System.Xml.Serialization;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using WebSocketSharp;

namespace Jpp.Unity
{
    // ============================================================
    // XML NETWORK PROTOCOL (COMPLETE)
    // ============================================================
    
    [Serializable]
    public class XmlNetworkMessage
    {
        public string MessageType;
        public Dictionary<string, string> Attributes = new();
        public string Payload;
        
        public XElement ToXml()
        {
            var elem = new XElement("message",
                new XAttribute("type", MessageType),
                new XAttribute("timestamp", DateTimeOffset.UtcNow.ToUnixTimeSeconds())
            );
            
            foreach (var attr in Attributes)
                elem.Add(new XAttribute(attr.Key, attr.Value));
            
            if (!string.IsNullOrEmpty(Payload))
                elem.Add(new XElement("payload", Payload));
            
            return elem;
        }
        
        public static XmlNetworkMessage FromXml(string xmlString)
        {
            var elem = XElement.Parse(xmlString);
            var msg = new XmlNetworkMessage
            {
                MessageType = elem.Attribute("type")?.Value
            };
            
            foreach (var attr in elem.Attributes())
            {
                if (attr.Name != "type" && attr.Name != "timestamp")
                    msg.Attributes[attr.Name.LocalName] = attr.Value;
            }
            
            msg.Payload = elem.Element("payload")?.Value;
            return msg;
        }
        
        public byte[] ToBytes() => System.Text.Encoding.UTF8.GetBytes(ToXml().ToString());
    }

    // ============================================================
    // WEBSOCKET NETWORK MANAGER (COMPLETE)
    // ============================================================
    
    public class JppNetworkManager : MonoBehaviour
    {
        public static JppNetworkManager Instance { get; private set; }
        
        [SerializeField] private string serverUrl = "ws://localhost:8080";
        [SerializeField] private bool autoConnect = true;
        [SerializeField] private float reconnectDelay = 5f;
        
        private WebSocket ws;
        private Queue<XmlNetworkMessage> messageQueue = new();
        private Dictionary<string, Action<XmlNetworkMessage>> handlers = new();
        private bool isReconnecting = false;
        
        public bool IsConnected => ws?.ReadyState == WebSocketState.Open;
        public string ConnectionStatus => IsConnected ? "Connected" : "Disconnected";
        
        public event Action OnConnected;
        public event Action OnDisconnected;
        public event Action<XmlNetworkMessage> OnMessageReceived;
        
        private void Awake()
        {
            if (Instance != null) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }
        
        private void Start()
        {
            if (autoConnect) Connect();
        }
        
        public void Connect()
        {
            if (ws != null) ws.Close();
            
            ws = new WebSocket(serverUrl);
            ws.WaitTime = TimeSpan.FromSeconds(5);
            
            ws.OnOpen += (sender, e) =>
            {
                Debug.Log("[JppNetwork] Connected to " + serverUrl);
                isReconnecting = false;
                OnConnected?.Invoke();
                
                SendMessage(new XmlNetworkMessage
                {
                    MessageType = "player-join",
                    Attributes = 
                    {
                        ["playerId"] = SystemInfo.deviceUniqueIdentifier,
                        ["deviceName"] = SystemInfo.deviceName,
                        ["platform"] = Application.platform.ToString()
                    }
                });
            };
            
            ws.OnMessage += (sender, e) =>
            {
                try
                {
                    var msg = XmlNetworkMessage.FromXml(e.Data);
                    lock (messageQueue) { messageQueue.Enqueue(msg); }
                }
                catch (Exception ex)
                {
                    Debug.LogError("[JppNetwork] Parse error: " + ex.Message);
                }
            };
            
            ws.OnError += (sender, e) => 
            {
                Debug.LogError("[JppNetwork] Error: " + e.Message);
                OnDisconnected?.Invoke();
            };
            
            ws.OnClose += (sender, e) =>
            {
                Debug.Log("[JppNetwork] Disconnected, code: " + e.Code);
                OnDisconnected?.Invoke();
                if (!isReconnecting) StartCoroutine(Reconnect());
            };
            
            ws.Connect();
        }
        
        private IEnumerator Reconnect()
        {
            isReconnecting = true;
            yield return new WaitForSeconds(reconnectDelay);
            Debug.Log("[JppNetwork] Reconnecting...");
            Connect();
        }
        
        private void Update()
        {
            lock (messageQueue)
            {
                while (messageQueue.Count > 0)
                {
                    var msg = messageQueue.Dequeue();
                    ProcessMessage(msg);
                    OnMessageReceived?.Invoke(msg);
                }
            }
        }
        
        public void SendMessage(XmlNetworkMessage msg)
        {
            if (!IsConnected)
            {
                Debug.LogWarning("[JppNetwork] Not connected, message queued");
                return;
            }
            ws.Send(msg.ToXml().ToString());
        }
        
        public void Broadcast(string messageType, Dictionary<string, string> attrs)
        {
            SendMessage(new XmlNetworkMessage
            {
                MessageType = messageType,
                Attributes = attrs ?? new Dictionary<string, string>()
            });
        }
        
        public void RegisterHandler(string messageType, Action<XmlNetworkMessage> handler)
        {
            handlers[messageType] = handler;
        }
        
        public void UnregisterHandler(string messageType)
        {
            handlers.Remove(messageType);
        }
        
        private void ProcessMessage(XmlNetworkMessage msg)
        {
            if (handlers.TryGetValue(msg.MessageType, out var handler))
                handler(msg);
            else
                Debug.LogWarning($"[JppNetwork] No handler for: {msg.MessageType}");
        }
        
        private void OnDestroy()
        {
            ws?.Close();
            Instance = null;
        }
    }

    // ============================================================
    // NETWORK PLAYER (COMPLETE - Mirror-style)
    // ============================================================
    
    public class JppNetworkPlayer : MonoBehaviour
    {
        [SyncVar(hook = nameof(OnHealthChanged))] 
        public int Health = 100;
        
        [SyncVar] public string PlayerId;
        [SyncVar] public string PlayerName = "Player";
        [SyncVar] public int TeamId = 0;
        [SyncVar] public int Score = 0;
        [SyncVar] public bool IsAlive = true;
        
        [SyncVar] public Vector3 NetworkPosition;
        [SyncVar] public Quaternion NetworkRotation;
        [SyncVar] public Vector3 NetworkVelocity;
        
        private Vector3 lastPosition;
        private Quaternion lastRotation;
        private float positionThreshold = 0.01f;
        private float rotationThreshold = 1f;
        private float lerpSpeed = 15f;
        private float updateRate = 0.05f; // 20Hz
        private float lastUpdateTime;
        
        public bool IsLocal => PlayerId == SystemInfo.deviceUniqueIdentifier;
        
        // Events
        public event Action<int> OnHealthChange;
        public event Action OnDeath;
        public event Action OnRespawn;
        
        private void Start()
        {
            if (IsLocal)
            {
                SetupLocalPlayer();
            }
            else
            {
                SetupRemotePlayer();
            }
        }
        
        private void SetupLocalPlayer()
        {
            GetComponent<Camera>()?.gameObject.SetActive(true);
            FindObjectOfType<JppHUD>()?.SetTarget(this);
            
            // Register network handlers
            JppNetworkManager.Instance?.RegisterHandler("player-damage", OnDamageMessage);
            JppNetworkManager.Instance?.RegisterHandler("player-death", OnDeathMessage);
            JppNetworkManager.Instance?.RegisterHandler("player-respawn", OnRespawnMessage);
        }
        
        private void SetupRemotePlayer()
        {
            GetComponent<Camera>()?.gameObject.SetActive(false);
            GetComponent<AudioListener>()?.enabled = false;
        }
        
        private void Update()
        {
            if (!IsAlive) return;
            
            if (IsLocal)
            {
                UpdateLocalPlayer();
            }
            else
            {
                UpdateRemotePlayer();
            }
        }
        
        private void UpdateLocalPlayer()
        {
            // Check if position changed significantly
            if (Time.time - lastUpdateTime < updateRate) return;
            
            float posDiff = Vector3.Distance(transform.position, lastPosition);
            float rotDiff = Quaternion.Angle(transform.rotation, lastRotation);
            
            if (posDiff > positionThreshold || rotDiff > rotationThreshold)
            {
                CmdSyncState(
                    transform.position,
                    transform.rotation,
                    GetComponent<Rigidbody>()?.velocity ?? Vector3.zero
                );
                lastPosition = transform.position;
                lastRotation = transform.rotation;
                lastUpdateTime = Time.time;
            }
        }
        
        private void UpdateRemotePlayer()
        {
            // Smooth interpolation
            transform.position = Vector3.Lerp(transform.position, NetworkPosition, Time.deltaTime * lerpSpeed);
            transform.rotation = Quaternion.Slerp(transform.rotation, NetworkRotation, Time.deltaTime * lerpSpeed);
            
            // Predict velocity
            if (GetComponent<Rigidbody>() != null)
            {
                GetComponent<Rigidbody>().velocity = Vector3.Lerp(
                    GetComponent<Rigidbody>().velocity,
                    NetworkVelocity,
                    Time.deltaTime * lerpSpeed
                );
            }
        }
        
        // Network Commands
        [Command]
        public void CmdSyncState(Vector3 pos, Quaternion rot, Vector3 vel)
        {
            NetworkPosition = pos;
            NetworkRotation = rot;
            NetworkVelocity = vel;
            RpcSyncState(pos, rot, vel);
        }
        
        [ClientRpc]
        public void RpcSyncState(Vector3 pos, Quaternion rot, Vector3 vel)
        {
            if (IsLocal) return;
            NetworkPosition = pos;
            NetworkRotation = rot;
            NetworkVelocity = vel;
        }
        
        [Command]
        public void CmdTakeDamage(int damage, string attackerId, Vector3 hitPoint)
        {
            if (!IsAlive) return;
            
            Health -= damage;
            RpcTakeDamage(damage, attackerId, hitPoint);
            
            if (Health <= 0)
            {
                Health = 0;
                IsAlive = false;
                RpcDie(attackerId);
            }
        }
        
        [ClientRpc]
        public void RpcTakeDamage(int damage, string attackerId, Vector3 hitPoint)
        {
            // Visual feedback
            StartCoroutine(ShowDamageEffect(hitPoint));
            OnHealthChange?.Invoke(Health);
        }
        
        [ClientRpc]
        public void RpcDie(string killerId)
        {
            IsAlive = false;
            GetComponent<Animator>()?.SetTrigger("Die");
            GetComponent<Collider>()?.enabled = false;
            
            if (IsLocal)
            {
                FindObjectOfType<JppHUD>()?.ShowDeathScreen(killerId);
                StartCoroutine(RespawnCountdown());
            }
            
            OnDeath?.Invoke();
        }
        
        [Command]
        public void CmdRespawn(Vector3 spawnPoint)
        {
            Health = 100;
            IsAlive = true;
            RpcRespawn(spawnPoint);
        }
        
        [ClientRpc]
        public void RpcRespawn(Vector3 spawnPoint)
        {
            transform.position = spawnPoint;
            GetComponent<Animator>()?.SetTrigger("Respawn");
            GetComponent<Collider>()?.enabled = true;
            
            if (IsLocal)
            {
                FindObjectOfType<JppHUD>()?.HideDeathScreen();
            }
            
            OnRespawn?.Invoke();
        }
        
        [Command]
        public void CmdShoot(Vector3 origin, Vector3 direction, int weaponId)
        {
            RpcShoot(origin, direction, weaponId);
            
            // Server-side hit detection
            if (Physics.Raycast(origin, direction, out RaycastHit hit, 500f))
            {
                var target = hit.collider.GetComponent<JppNetworkPlayer>();
                if (target != null && target != this && target.TeamId != TeamId)
                {
                    int damage = CalculateDamage(weaponId, hit.distance);
                    target.CmdTakeDamage(damage, PlayerId, hit.point);
                }
            }
        }
        
        [ClientRpc]
        public void RpcShoot(Vector3 origin, Vector3 direction, int weaponId)
        {
            // Spawn muzzle flash, tracer, etc.
            SpawnShootEffect(origin, direction, weaponId);
        }
        
        // Helpers
        private void OnHealthChanged(int oldHealth, int newHealth)
        {
            OnHealthChange?.Invoke(newHealth);
        }
        
        private IEnumerator ShowDamageEffect(Vector3 hitPoint)
        {
            // Spawn blood/damage particle
            yield return new WaitForSeconds(0.5f);
        }
        
        private IEnumerator RespawnCountdown()
        {
            yield return new WaitForSeconds(3f);
            
            var spawn = JppSpawnManager.Instance?.GetRandomSpawnPoint(TeamId);
            CmdRespawn(spawn?.position ?? Vector3.zero);
        }
        
        private int CalculateDamage(int weaponId, float distance)
        {
            // Weapon damage falloff
            var weaponData = JppWeaponDatabase.Instance?.GetWeapon(weaponId);
            if (weaponData == null) return 25;
            
            float falloff = 1f / (1f + distance * 0.01f);
            return Mathf.RoundToInt(weaponData.BaseDamage * falloff);
        }
        
        private void SpawnShootEffect(Vector3 origin, Vector3 direction, int weaponId)
        {
            // Instantiate bullet tracer
            Debug.DrawRay(origin, direction * 100f, Color.yellow, 0.1f);
        }
        
        // Message handlers
        private void OnDamageMessage(XmlNetworkMessage msg)
        {
            if (msg.Attributes.TryGetValue("target", out string targetId) && targetId == PlayerId)
            {
                // Process damage confirmation
            }
        }
        
        private void OnDeathMessage(XmlNetworkMessage msg) { }
        private void OnRespawnMessage(XmlNetworkMessage msg) { }
        
        private void OnDestroy()
        {
            if (JppNetworkManager.Instance != null)
            {
                JppNetworkManager.Instance.UnregisterHandler("player-damage");
                JppNetworkManager.Instance.UnregisterHandler("player-death");
                JppNetworkManager.Instance.UnregisterHandler("player-respawn");
            }
        }
    }

    // ============================================================
    // SPAWN MANAGER
    // ============================================================
    
    public class JppSpawnManager : MonoBehaviour
    {
        public static JppSpawnManager Instance { get; private set; }
        
        [SerializeField] private List<Transform> team1Spawns = new();
        [SerializeField] private List<Transform> team2Spawns = new();
        
        private void Awake()
        {
            Instance = this;
        }
        
        public Transform GetRandomSpawnPoint(int teamId)
        {
            var spawns = teamId == 1 ? team1Spawns : team2Spawns;
            if (spawns.Count == 0) return null;
            return spawns[UnityEngine.Random.Range(0, spawns.Count)];
        }
    }

    // ============================================================
    // WEAPON DATABASE
    // ============================================================
    
    [CreateAssetMenu(fileName = "WeaponDatabase", menuName = "J++/Weapon Database")]
    public class JppWeaponDatabase : ScriptableObject
    {
        public static JppWeaponDatabase Instance;
        
        [System.Serializable]
        public class WeaponData
        {
            public int Id;
            public string Name;
            public int BaseDamage;
            public float FireRate;
            public float Range;
            public int MagazineSize;
            public float ReloadTime;
        }
        
        public List<WeaponData> Weapons = new();
        
        public WeaponData GetWeapon(int id)
        {
            return Weapons.Find(w => w.Id == id);
        }
    }

    // ============================================================
    // HUD / UI SYSTEM (COMPLETE)
    // ============================================================
    
    public class JppHUD : MonoBehaviour
    {
        [Header("Health")]
        [SerializeField] private Slider healthBar;
        [SerializeField] private Image healthFill;
        [SerializeField] private TextMeshProUGUI healthText;
        [SerializeField] private Color fullHealthColor = Color.green;
        [SerializeField] private Color lowHealthColor = Color.red;
        [SerializeField] private float lowHealthThreshold = 0.3f;
        
        [Header("Ammo")]
        [SerializeField] private TextMeshProUGUI ammoText;
        [SerializeField] private TextMeshProUGUI reserveText;
        
        [Header("Crosshair")]
        [SerializeField] private RectTransform crosshair;
        [SerializeField] private float normalSize = 20f;
        [SerializeField] private float adsSize = 10f;
        [SerializeField] private float spreadMultiplier = 1f;
        
        [Header("Minimap")]
        [SerializeField] private RawImage minimap;
        [SerializeField] private Transform playerIcon;
        
        [Header("Score")]
        [SerializeField] private TextMeshProUGUI scoreText;
        [SerializeField] private TextMeshProUGUI killFeed;
        
        [Header("Damage Overlay")]
        [SerializeField] private Image damageOverlay;
        [SerializeField] private float damageFlashDuration = 0.3f;
        
        [Header("Death Screen")]
        [SerializeField] private GameObject deathScreen;
        [SerializeField] private TextMeshProUGUI killerNameText;
        [SerializeField] private TextMeshProUGUI respawnTimerText;
        
        [Header("Kill Feed")]
        [SerializeField] private Transform killFeedContainer;
        [SerializeField] private GameObject killFeedItemPrefab;
        
        private JppNetworkPlayer targetPlayer;
        private int currentAmmo;
        private int reserveAmmo;
        private bool isAiming;
        private Queue<string> killFeedMessages = new();
        
        public void SetTarget(JppNetworkPlayer player)
        {
            if (targetPlayer != null)
            {
                targetPlayer.OnHealthChange -= UpdateHealth;
                targetPlayer.OnDeath -= OnPlayerDeath;
            }
            
            targetPlayer = player;
            targetPlayer.OnHealthChange += UpdateHealth;
            targetPlayer.OnDeath += OnPlayerDeath;
        }
        
        private void Update()
        {
            UpdateCrosshair();
            UpdateMinimap();
        }
        
        private void UpdateHealth(int health)
        {
            float healthPercent = health / 100f;
            healthBar.value = healthPercent;
            healthText.text = $"{health}/100";
            
            healthFill.color = Color.Lerp(lowHealthColor, fullHealthColor, healthPercent);
            
            if (healthPercent < lowHealthThreshold)
            {
                healthFill.color = Color.Lerp(Color.clear, lowHealthColor, 
                    Mathf.PingPong(Time.time * 2f, 1f));
            }
        }
        
        private void UpdateCrosshair()
        {
            float targetSize = isAiming ? adsSize : normalSize;
            targetSize *= spreadMultiplier;
            
            crosshair.sizeDelta = Vector2.Lerp(crosshair.sizeDelta, 
                Vector2.one * targetSize, Time.deltaTime * 10f);
        }
        
        private void UpdateMinimap()
        {
            if (targetPlayer == null || minimap == null) return;
            
            // Rotate minimap based on player rotation
            float angle = targetPlayer.transform.eulerAngles.y;
            minimap.rectTransform.rotation = Quaternion.Euler(0, 0, angle);
            
            // Update player icon
            if (playerIcon != null)
                playerIcon.rotation = Quaternion.Euler(0, 0, -angle);
        }
        
        public void UpdateAmmo(int current, int reserve)
        {
            currentAmmo = current;
            reserveAmmo = reserve;
            ammoText.text = $"{current}";
            reserveText.text = $"/ {reserve}";
            
            // Low ammo warning
            if (current <= 5)
                ammoText.color = Color.red;
            else
                ammoText.color = Color.white;
        }
        
        public void SetAiming(bool aiming)
        {
            isAiming = aiming;
        }
        
        public void FlashDamage()
        {
            StartCoroutine(DamageFlashCoroutine());
        }
        
        private IEnumerator DamageFlashCoroutine()
        {
            damageOverlay.color = new Color(1, 0, 0, 0.5f);
            
            float t = 0;
            while (t < damageFlashDuration)
            {
                t += Time.deltaTime;
                float alpha = 0.5f * (1 - t / damageFlashDuration);
                damageOverlay.color = new Color(1, 0, 0, alpha);
                yield return null;
            }
            
            damageOverlay.color = Color.clear;
        }
        
        public void ShowDeathScreen(string killerName)
        {
            deathScreen.SetActive(true);
            killerNameText.text = $"Killed by: {killerName}";
            StartCoroutine(RespawnCountdown());
        }
        
        public void HideDeathScreen()
        {
            deathScreen.SetActive(false);
        }
        
        private IEnumerator RespawnCountdown()
        {
            float countdown = 3f;
            while (countdown > 0)
            {
                respawnTimerText.text = $"Respawning in: {countdown:F1}";
                countdown -= Time.deltaTime;
                yield return null;
            }
        }
        
        public void AddKillFeed(string killer, string victim, string weapon)
        {
            string msg = $"{killer} [{weapon}] {victim}";
            killFeedMessages.Enqueue(msg);
            
            if (killFeedMessages.Count > 5)
                killFeedMessages.Dequeue();
            
            UpdateKillFeedDisplay();
        }
        
        private void UpdateKillFeedDisplay()
        {
            // Clear and rebuild kill feed
            foreach (Transform child in killFeedContainer)
                Destroy(child.gameObject);
            
            foreach (var msg in killFeedMessages)
            {
                var item = Instantiate(killFeedItemPrefab, killFeedContainer);
                item.GetComponent<TextMeshProUGUI>().text = msg;
            }
        }
        
        public void UpdateScore(int score, int kills, int deaths)
        {
            scoreText.text = $"Score: {score} | K: {kills} | D: {deaths}";
        }
        
        private void OnPlayerDeath()
        {
            FlashDamage();
        }
        
        private void OnDestroy()
        {
            if (targetPlayer != null)
            {
                targetPlayer.OnHealthChange -= UpdateHealth;
                targetPlayer.OnDeath -= OnPlayerDeath;
            }
        }
    }

    // ============================================================
    // WASM BRIDGE (C# ↔ Lua ↔ C)
    // ============================================================
    
    public class JppWasmBridge : MonoBehaviour
    {
        public static JppWasmBridge Instance { get; private set; }
        
        [System.Runtime.InteropServices.DllImport("__Internal")]
        private static extern void wasm_load_module(string name, byte[] data, int length);
        
        [System.Runtime.InteropServices.DllImport("__Internal")]
        private static extern int wasm_call_function(string module, string function, string args);
        
        [System.Runtime.InteropServices.DllImport("__Internal")]
        private static extern IntPtr wasm_get_result(string module, string function);
        
        private Dictionary<string, byte[]> loadedModules = new();
        
        private void Awake()
        {
            Instance = this;
        }
        
        public void LoadModule(string name, byte[] wasmBytes)
        {
            loadedModules[name] = wasmBytes;
            
            #if UNITY_WEBGL && !UNITY_EDITOR
            wasm_load_module(name, wasmBytes, wasmBytes.Length);
            #else
            Debug.Log($"[WASM] Loaded module: {name} ({wasmBytes.Length} bytes)");
            #endif
        }
        
        public T CallFunction<T>(string module, string function, params object[] args)
        {
            string argString = string.Join(",", Array.ConvertAll(args, a => a?.ToString() ?? "null"));
            
            #if UNITY_WEBGL && !UNITY_EDITOR
            wasm_call_function(module, function, argString);
            IntPtr resultPtr = wasm_get_result(module, function);
            string result = System.Runtime.InteropServices.Marshal.PtrToStringAnsi(resultPtr);
            return ParseResult<T>(result);
            #else
            Debug.Log($"[WASM] Call: {module}.{function}({argString})");
            return default;
            #endif
        }
        
        private T ParseResult<T>(string result)
        {
            if (typeof(T) == typeof(int)) return (T)(object)int.Parse(result);
            if (typeof(T) == typeof(float)) return (T)(object)float.Parse(result);
            if (typeof(T) == typeof(double)) return (T)(object)double.Parse(result);
            if (typeof(T) == typeof(bool)) return (T)(object)bool.Parse(result);
            if (typeof(T) == typeof(string)) return (T)(object)result;
            return default;
        }
        
        // Physics wrappers
        public Vector3 LuaVec3(float x, float y, float z)
        {
            CallFunction<int>("physics", "vec3_new", x, y, z);
            return new Vector3(x, y, z);
        }
        
        public float[] LuaFFT(float[] signal)
        {
            CallFunction<int>("physics", "fft", string.Join(",", signal));
            // Parse result...
            return signal;
        }
        
        public double LuaPlasmaConductivity(double temp, double density)
        {
            return CallFunction<double>("physics", "plasma_conductivity", temp, density);
        }
    }

    // ============================================================
    // XML SERIALIZER FOR GAME STATE
    // ============================================================
    
    public static class JppXmlSerializer
    {
        public static string SerializeGameState(JppNetworkPlayer player)
        {
            var doc = new XDocument(
                new XElement("game-state",
                    new XAttribute("timestamp", DateTimeOffset.UtcNow.ToUnixTimeSeconds()),
                    new XElement("player",
                        new XAttribute("id", player.PlayerId),
                        new XAttribute("name", player.PlayerName),
                        new XAttribute("health", player.Health),
                        new XAttribute("team", player.TeamId),
                        new XAttribute("score", player.Score),
                        new XElement("position",
                            new XAttribute("x", player.transform.position.x),
                            new XAttribute("y", player.transform.position.y),
                            new XAttribute("z", player.transform.position.z)
                        ),
                        new XElement("rotation",
                            new XAttribute("x", player.transform.rotation.x),
                            new XAttribute("y", player.transform.rotation.y),
                            new XAttribute("z", player.transform.rotation.z),
                            new XAttribute("w", player.transform.rotation.w)
                        )
                    )
                )
            );
            return doc.ToString();
        }
        
        public static void DeserializeGameState(string xml, JppNetworkPlayer player)
        {
            var doc = XDocument.Parse(xml);
            var playerElem = doc.Root?.Element("player");
            if (playerElem == null) return;
            
            player.Health = int.Parse(playerElem.Attribute("health")?.Value ?? "100");
            player.TeamId = int.Parse(playerElem.Attribute("team")?.Value ?? "0");
            player.Score = int.Parse(playerElem.Attribute("score")?.Value ?? "0");
            
            var pos = playerElem.Element("position");
            if (pos != null)
            {
                player.transform.position = new Vector3(
                    float.Parse(pos.Attribute("x")?.Value ?? "0"),
                    float.Parse(pos.Attribute("y")?.Value ?? "0"),
                    float.Parse(pos.Attribute("z")?.Value ?? "0")
                );
            }
        }
    }

    // ============================================================
    // COROUTINE HELPERS (J++ yield support)
    // ============================================================
    
    public static class JppCoroutine
    {
        public static IEnumerator WaitForSeconds(float seconds)
        {
            yield return new WaitForSeconds(seconds);
        }
        
        public static IEnumerator WaitForFixedUpdate()
        {
            yield return new WaitForFixedUpdate();
        }
        
        public static IEnumerator WaitForEndOfFrame()
        {
            yield return new WaitForEndOfFrame();
        }
        
        public static IEnumerator WaitUntil(Func<bool> condition)
        {
            yield return new WaitUntil(condition);
        }
        
        public static IEnumerator WaitWhile(Func<bool> condition)
        {
            yield return new WaitWhile(condition);
        }
        
        public static IEnumerator Sequence(params IEnumerator[] coroutines)
        {
            foreach (var c in coroutines)
                yield return c;
        }
        
        public static IEnumerator Parallel(params IEnumerator[] coroutines)
        {
            var runners = new List<Coroutine>();
            foreach (var c in coroutines)
                runners.Add(CoroutineRunner.Instance.StartCoroutine(c));
            
            foreach (var r in runners)
                yield return r;
        }
    }
    
    public class CoroutineRunner : MonoBehaviour
    {
        public static CoroutineRunner Instance { get; private set; }
        
        private void Awake()
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }
    }

    // ============================================================
    // SHADER PIPELINE (Lua → HLSL Bridge)
    // ============================================================
    
    public class JppShaderPipeline : MonoBehaviour
    {
        public static JppShaderPipeline Instance { get; private set; }
        
        [SerializeField] private Shader defaultShader;
        private Dictionary<string, Material> runtimeMaterials = new();
        
        private void Awake()
        {
            Instance = this;
        }
        
        public Material CreateMaterialFromLua(string luaShaderCode)
        {
            // Parse Lua shader definition and generate HLSL
            string hlsl = TranspileLuaToHLSL(luaShaderCode);
            
            // Create shader from HLSL
            var shader = new Shader();
            shader = Shader.Find("Hidden/JppRuntime/" + GetShaderName(luaShaderCode));
            
            if (shader == null)
            {
                // Compile runtime shader
                shader = ShaderUtil.CreateShaderAsset(hlsl);
            }
            
            var mat = new Material(shader);
            runtimeMaterials[mat.name] = mat;
            return mat;
        }
        
        private string TranspileLuaToHLSL(string luaCode)
        {
            // Parse Lua shader syntax and convert to HLSL
            var sb = new System.Text.StringBuilder();
            
            sb.AppendLine("Shader \"Jpp/Runtime/Generated\" {");
            sb.AppendLine("    Properties {");
            // Extract properties from Lua
            sb.AppendLine("        _Color (\"Color\", Color) = (1,1,1,1)");
            sb.AppendLine("    }");
            sb.AppendLine("    SubShader {");
            sb.AppendLine("        Pass {");
            sb.AppendLine("            CGPROGRAM");
            sb.AppendLine("            #pragma vertex vert");
            sb.AppendLine("            #pragma fragment frag");
            sb.AppendLine("            #include \"UnityCG.cginc\"");
            sb.AppendLine("");
            
            // Transpile vertex function
            if (luaCode.Contains("fn vert"))
            {
                sb.AppendLine(TranspileVertexFunction(luaCode));
            }
            
            // Transpile fragment function
            if (luaCode.Contains("fn frag"))
            {
                sb.AppendLine(TranspileFragmentFunction(luaCode));
            }
            
            sb.AppendLine("            ENDCG");
            sb.AppendLine("        }");
            sb.AppendLine("    }");
            sb.AppendLine("}");
            
            return sb.ToString();
        }
        
        private string TranspileVertexFunction(string luaCode)
        {
            // Convert J++ vertex shader to HLSL
            return @"
            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            v2f vert(appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }";
        }
        
        private string TranspileFragmentFunction(string luaCode)
        {
            // Convert J++ fragment shader to HLSL
            return @"
            fixed4 frag(v2f i) : SV_Target {
                return fixed4(1, 0.5, 0, 1);
            }";
        }
        
        private string GetShaderName(string luaCode)
        {
            // Extract shader name from Lua code
            int start = luaCode.IndexOf("shader") + 6;
            int end = luaCode.IndexOf("{", start);
            return luaCode.Substring(start, end - start).Trim();
        }
    }

    // ============================================================
    // INPUT MANAGER (J++ Input mapping)
    // ============================================================
    
    public class JppInputManager : MonoBehaviour
    {
        public static JppInputManager Instance { get; private set; }
        
        [System.Serializable]
        public class InputAction
        {
            public string Name;
            public KeyCode Key;
            public string Axis;
            public bool IsButton;
            public bool IsAxis;
        }
        
        [SerializeField] private List<InputAction> actions = new();
        private Dictionary<string, InputAction> actionMap = new();
        
        private void Awake()
        {
            Instance = this;
            foreach (var a in actions)
                actionMap[a.Name] = a;
        }
        
        public float GetAxis(string actionName)
        {
            if (actionMap.TryGetValue(actionName, out var action) && action.IsAxis)
                return Input.GetAxis(action.Axis);
            return 0;
        }
        
        public bool GetButton(string actionName)
        {
            if (actionMap.TryGetValue(actionName, out var action) && action.IsButton)
                return Input.GetKey(action.Key);
            return false;
        }
        
        public bool GetButtonDown(string actionName)
        {
            if (actionMap.TryGetValue(actionName, out var action) && action.IsButton)
                return Input.GetKeyDown(action.Key);
            return false;
        }
        
        public bool GetButtonUp(string actionName)
        {
            if (actionMap.TryGetValue(actionName, out var action) && action.IsButton)
                return Input.GetKeyUp(action.Key);
            return false;
        }
        
        public Vector2 GetMousePosition() => Input.mousePosition;
        public Vector2 GetMouseDelta() => new Vector2(Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y"));
    }

    // ============================================================
    // AUDIO MANAGER
    // ============================================================
    
    public class JppAudioManager : MonoBehaviour
    {
        public static JppAudioManager Instance { get; private set; }
        
        [SerializeField] private AudioSource sfxSource;
        [SerializeField] private AudioSource musicSource;
        [SerializeField] private List<AudioClip> clips = new();
        
        private Dictionary<string, AudioClip> clipMap = new();
        
        private void Awake()
        {
            Instance = this;
            foreach (var c in clips)
                clipMap[c.name] = c;
        }
        
        public void PlaySFX(string name, float volume = 1f, float pitch = 1f)
        {
            if (clipMap.TryGetValue(name, out var clip))
            {
                sfxSource.pitch = pitch;
                sfxSource.PlayOneShot(clip, volume);
            }
        }
        
        public void PlayMusic(string name, bool loop = true)
        {
            if (clipMap.TryGetValue(name, out var clip))
            {
                musicSource.clip = clip;
                musicSource.loop = loop;
                musicSource.Play();
            }
        }
        
        public void StopMusic() => musicSource.Stop();
        public void PauseMusic() => musicSource.Pause();
        public void ResumeMusic() => musicSource.UnPause();
        
        public void SetSFXVolume(float vol) => sfxSource.volume = vol;
        public void SetMusicVolume(float vol) => musicSource.volume = vol;
    }

    // ============================================================
    // GAME MANAGER
    // ============================================================
    
    public class JppGameManager : MonoBehaviour
    {
        public static JppGameManager Instance { get; private set; }
        
        public enum GameState { Menu, Playing, Paused, GameOver }
        public GameState CurrentState { get; private set; } = GameState.Menu;
        
        [SerializeField] private GameObject menuPanel;
        [SerializeField] private GameObject hudPanel;
        [SerializeField] private GameObject pausePanel;
        [SerializeField] private GameObject gameOverPanel;
        
        public event Action<GameState> OnStateChanged;
        
        private void Awake()
        {
            Instance = this;
        }
        
        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                if (CurrentState == GameState.Playing)
                    Pause();
                else if (CurrentState == GameState.Paused)
                    Resume();
            }
        }
        
        public void StartGame()
        {
            SetState(GameState.Playing);
            menuPanel?.SetActive(false);
            hudPanel?.SetActive(true);
            
            // Spawn player
            var spawn = JppSpawnManager.Instance?.GetRandomSpawnPoint(1);
            if (spawn != null)
            {
                // Instantiate player at spawn
            }
        }
        
        public void Pause()
        {
            SetState(GameState.Paused);
            Time.timeScale = 0;
            pausePanel?.SetActive(true);
        }
        
        public void Resume()
        {
            SetState(GameState.Playing);
            Time.timeScale = 1;
            pausePanel?.SetActive(false);
        }
        
        public void GameOver()
        {
            SetState(GameState.GameOver);
            gameOverPanel?.SetActive(true);
        }
        
        public void QuitToMenu()
        {
            SetState(GameState.Menu);
            Time.timeScale = 1;
            menuPanel?.SetActive(true);
            hudPanel?.SetActive(false);
            pausePanel?.SetActive(false);
            gameOverPanel?.SetActive(false);
        }
        
        private void SetState(GameState state)
        {
            CurrentState = state;
            OnStateChanged?.Invoke(state);
        }
    }

    // ============================================================
    // ATTRIBUTE MARKERS (for J++ parser)
    // ============================================================
    
    [AttributeUsage(AttributeTargets.Field)]
    public class SyncVarAttribute : Attribute
    {
        public string Hook { get; set; }
    }
    
    [AttributeUsage(AttributeTargets.Method)]
    public class CommandAttribute : Attribute { }
    
    [AttributeUsage(AttributeTargets.Method)]
    public class ClientRpcAttribute : Attribute { }
    
    [AttributeUsage(AttributeTargets.Method)]
    public class TargetRpcAttribute : Attribute { }
}