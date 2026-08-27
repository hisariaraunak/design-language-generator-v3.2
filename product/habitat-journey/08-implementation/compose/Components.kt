import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics

object HJDimens { const val ButtonHeight = 52; const val TouchTarget = 44 }

@Composable fun HJButton(label: String, onClick: () -> Unit) {
    Button(onClick = onClick) { Text(label) }
}

@Composable fun HJCalorieRing(remaining: Int, goal: Int) {
    Text("$remaining kcal left", Modifier.semantics { contentDescription = "$remaining calories left out of $goal" })
}
