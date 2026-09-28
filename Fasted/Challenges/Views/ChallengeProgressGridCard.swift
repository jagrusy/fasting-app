import SwiftUI

/// Grid showing non-punitive calendar dots progress for a challenge.
struct ChallengeProgressGridCard: View {
    let challenge: Challenge
    let currentNow: Date

    init(challenge: Challenge, currentNow: Date) {
        self.challenge = challenge
        self.currentNow = currentNow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenge Journey")
                .font(.headline)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            let today = challenge.calendar.startOfDay(for: currentNow)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<challenge.dayCount, id: \.self) { offset in
                    if let day = challenge.calendar.date(byAdding: .day, value: offset, to: challenge.startDate) {
                        dayDot(day: day, today: today, dayNumber: offset + 1)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Gaps are part of practice — keep going.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dayDot(day: Date, today: Date, dayNumber: Int) -> some View {
        let isToday = day == today
        let isFuture = day > today
        let isDone = isDayFullyCompleted(day)

        return ZStack {
            Circle()
                .fill(
                    isFuture ? Color(.systemGray5) :
                    isDone ? Color.green.opacity(0.85) :
                    Color(.systemGray4)
                )
                .frame(width: 28, height: 28)

            if isToday {
                Circle()
                    .strokeBorder(SolsticeColors.solarAmber, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }

            Text("\(dayNumber)")
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .foregroundStyle(isFuture ? Color.secondary : Color.white)
        }
    }

    private func isDayFullyCompleted(_ day: Date) -> Bool {
        let scheduled = challenge.commitments.filter {
            let weekday = challenge.calendar.component(.weekday, from: day)
            return $0.draft.weekdays.contains(weekday)
        }
        guard !scheduled.isEmpty else { return false }
        return scheduled.allSatisfy { commitment in
            challenge.checkIns.contains {
                $0.commitmentID == commitment.id && $0.day == day && $0.status == .done
            }
        }
    }
}
