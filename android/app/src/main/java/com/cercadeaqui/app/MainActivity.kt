package com.cercadeaqui.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

private val Night = Color(0xFF10172A)
private val Indigo = Color(0xFF635BFF)
private val Coral = Color(0xFFFF6B7A)
private val SurfaceCard = Color(0xFF1B2540)

data class Listing(
    val id: String,
    val title: String,
    val category: String,
    val locality: String,
    val description: String,
    val phone: String
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { CercaApp() }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CercaApp() {
    var listings by remember { mutableStateOf<List<Listing>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var query by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("Todos") }
    val categories = listOf("Todos", "Comercios", "Servicios", "Ofertas", "Eventos", "Hostelería", "Hogar", "Otros")

    LaunchedEffect(Unit) {
        try {
            listings = withContext(Dispatchers.IO) { SupabaseListings.load() }
        } catch (e: Exception) {
            error = "No se han podido cargar los negocios. Comprueba tu conexión e inténtalo de nuevo."
        } finally { loading = false }
    }

    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Indigo, secondary = Coral, background = Night,
            surface = SurfaceCard, onBackground = Color.White, onSurface = Color.White
        )
    ) {
        Scaffold(containerColor = Night) { padding ->
            Column(Modifier.fillMaxSize().padding(padding)) {
                Column(
                    Modifier.fillMaxWidth().background(Night).padding(horizontal = 20.dp, vertical = 18.dp)
                ) {
                    Text("CERCA DE AQUÍ", color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Black)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.LocationOn, null, tint = Coral, modifier = Modifier.size(17.dp))
                        Text("Pilar · Torre · Mil Palmeras", color = Color.LightGray, fontSize = 13.sp)
                    }
                    Spacer(Modifier.height(16.dp))
                    OutlinedTextField(
                        value = query, onValueChange = { query = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("Buscar negocios y servicios") },
                        leadingIcon = { Icon(Icons.Default.Search, null) },
                        singleLine = true,
                        shape = RoundedCornerShape(16.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Indigo, unfocusedBorderColor = Color(0xFF46516D),
                            focusedTextColor = Color.White, unfocusedTextColor = Color.White
                        )
                    )
                    Spacer(Modifier.height(12.dp))
                    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(categories) { item ->
                            FilterChip(
                                selected = category == item,
                                onClick = { category = item },
                                label = { Text(item) },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = Indigo, selectedLabelColor = Color.White
                                )
                            )
                        }
                    }
                }
                when {
                    loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Coral)
                    }
                    error != null -> Column(Modifier.fillMaxWidth().padding(24.dp)) {
                        Text(error!!, color = Color.White)
                        Spacer(Modifier.height(10.dp))
                        Button(onClick = {
                            loading = true; error = null
                        }) { Text("Volver a intentar") }
                    }
                    else -> {
                        val filtered = listings.filter {
                            (category == "Todos" || it.category == category) &&
                            (query.isBlank() || listOf(it.title, it.description, it.locality, it.category)
                                .any { value -> value.contains(query, ignoreCase = true) })
                        }
                        if (filtered.isEmpty()) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                Text(if (listings.isEmpty()) "Todavía no hay negocios publicados." else "No hay resultados.", color = Color.LightGray)
                            }
                        } else LazyColumn(
                            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(filtered, key = { it.id }) { listing -> ListingCard(listing) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ListingCard(item: Listing) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = SurfaceCard)
    ) {
        Column(Modifier.padding(17.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(color = Indigo.copy(alpha = .22f), shape = RoundedCornerShape(50)) {
                    Text(item.category, Modifier.padding(horizontal = 10.dp, vertical = 5.dp), color = Color(0xFFBDB8FF), fontSize = 11.sp)
                }
                Spacer(Modifier.weight(1f))
                Text(item.locality, color = Color.LightGray, fontSize = 12.sp)
            }
            Spacer(Modifier.height(9.dp))
            Text(item.title, color = Color.White, fontSize = 19.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(5.dp))
            Text(item.description, color = Color(0xFFD0D5E2), fontSize = 14.sp)
            if (item.phone.isNotBlank()) {
                Spacer(Modifier.height(9.dp))
                Text("Teléfono: " + item.phone, color = Coral, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            }
        }
    }
}

private object SupabaseListings {
    fun load(): List<Listing> {
        val fields = "id,title,category,locality,description,contact_phone"
        val endpoint = BuildConfig.SUPABASE_URL +
            "/rest/v1/cerca_listings?select=" + URLEncoder.encode(fields, "UTF-8") +
            "&publication_status=eq.published&payment_status=eq.verified&order=created_at.desc"
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 12000
            readTimeout = 12000
            setRequestProperty("apikey", BuildConfig.SUPABASE_ANON_KEY)
            setRequestProperty("Authorization", "Bearer " + BuildConfig.SUPABASE_ANON_KEY)
            setRequestProperty("Accept", "application/json")
        }
        try {
            val code = connection.responseCode
            if (code !in 200..299) error("Supabase HTTP $code")
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val array = JSONArray(body)
            return (0 until array.length()).map { i ->
                val row = array.getJSONObject(i)
                Listing(
                    id = row.optString("id"), title = row.optString("title"),
                    category = row.optString("category"), locality = row.optString("locality"),
                    description = row.optString("description"), phone = row.optString("contact_phone")
                )
            }
        } finally { connection.disconnect() }
    }
}
